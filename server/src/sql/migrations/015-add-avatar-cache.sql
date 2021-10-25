ALTER TABLE jasb.users
  ADD COLUMN IF NOT EXISTS avatar_cache TEXT;

CREATE OR REPLACE FUNCTION jasb.avatar_key(
  "user" jasb.users
)
  RETURNS JSONB
  LANGUAGE PLPGSQL IMMUTABLE
AS $$
BEGIN
  RETURN CASE
   WHEN "user".avatar IS NULL THEN JSONB_BUILD_OBJECT(
     'discriminator', (("user".discriminator::INT) % 5)::TEXT
   )
   ELSE JSONB_BUILD_OBJECT(
     'user', "user".id,
     'avatar', "user".avatar
   )
 END;
END
$$;

CREATE TABLE IF NOT EXISTS jasb.cached_avatars (
  url TEXT NOT NULL,
  key JSONB NOT NULL,

  PRIMARY KEY (url),
  UNIQUE (key)
);

CREATE OR REPLACE FUNCTION jasb.login(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  given_name users.name%TYPE,
  given_discriminator users.discriminator%TYPE,
  given_avatar users.avatar%TYPE,
  given_access_token sessions.access_token%TYPE,
  given_refresh_token sessions.refresh_token%TYPE,
  discord_expires_in INTERVAL,
  initial_balance users.balance%TYPE
)
  RETURNS SETOF jasb.sessions
  LANGUAGE PLPGSQL
AS $$
  DECLARE
    new_user BOOLEAN;
  BEGIN
    INSERT INTO
      jasb.users (id, name, discriminator, avatar, balance)
    VALUES (
      user_id,
      given_name,
      given_discriminator,
      given_avatar,
      initial_balance
    )
    ON CONFLICT ON CONSTRAINT users_pkey DO UPDATE SET
      name = excluded.name,
      discriminator = excluded.discriminator,
      avatar = excluded.avatar,
      avatar_cache = CASE 
        WHEN users.avatar = excluded.avatar THEN users.avatar_cache
        ELSE (SELECT url FROM jasb.cached_avatars WHERE jasb.avatar_key(users.*) = cached_avatars.key)
      END
    RETURNING (xmax = 0) INTO new_user;

    RETURN QUERY
      INSERT INTO jasb.sessions ("user", session, access_token, refresh_token, discord_expires)
      VALUES (
        user_id,
        given_session,
        given_access_token,
        given_refresh_token,
        (NOW() + discord_expires_in)
      ) RETURNING *;

    IF new_user THEN
      INSERT INTO jasb.audit_logs ("user", event) VALUES (
        user_id,
        json_build_object(
          'event', 'CreateAccount',
          'balance', initial_balance
        )
      );
      INSERT INTO jasb.notifications ("for", notification) VALUES (
        user_id,
        json_build_object(
          'type', 'Gifted',
          'amount', initial_balance,
          'reason', 'AccountCreated'
        )
      );
    END IF;
  END;
$$;

CREATE OR REPLACE VIEW jasb.users_with_stakes AS
  WITH active_stakes AS (
    SELECT 
      stakes.amount,
      stakes.owner
    FROM stakes INNER JOIN bets ON stakes.game = bets.game AND stakes.bet = bets.id
    WHERE is_active(bets.progress)
  )
  SELECT
    users.id,
    users.name,
    users.discriminator,
    users.avatar,
    users.created,
    users.admin,
    users.balance,
    COALESCE(SUM(active_stakes.amount)::INT, 0) AS staked,
    users.avatar_cache
  FROM
    users LEFT JOIN
    active_stakes ON users.id = active_stakes.owner
  GROUP BY users.id;

CREATE OR REPLACE VIEW jasb.leaderboard AS
  SELECT
    users.id,
    users.name,
    users.discriminator,
    users.avatar,
    users.created,
    users.admin,
    users.balance,
    users.staked,
    (staked + balance) AS net_worth,
    RANK() OVER (
      ORDER BY (staked + balance) DESC
    ) rank,
    users.avatar_cache
  FROM jasb.users_with_stakes AS users;

CREATE OR REPLACE VIEW jasb.feed_notable_stakes AS
  SELECT
    games.id AS game,
    bets.id AS bet,
    stakes.made_at AS time,
    JSONB_BUILD_OBJECT(
      'type', 'NotableStake',
      'game', JSONB_BUILD_OBJECT('id', games.id, 'name', games.name),
      'bet', JSONB_BUILD_OBJECT('id', bets.id, 'name', bets.name),
      'spoiler', bets.spoiler,
      'option', JSONB_BUILD_OBJECT('id', options.id, 'name', options.name),
      'user', JSONB_BUILD_OBJECT(
        'id', users.id,
        'name', users.name,
        'discriminator', users.discriminator,
        'avatar', users.avatar,
        'avatar_cache', users.avatar_cache
      ),
      'message', stakes.message,
      'stake', stakes.amount
    ) AS item
  FROM
    stakes INNER JOIN
    games ON games.id = stakes.game INNER JOIN
    bets ON bets.id = stakes.bet AND bets.game = stakes.game INNER JOIN
    options ON
      options.game = stakes.game AND
      options.bet = stakes.bet AND
      options.id = stakes.option INNER JOIN
    users ON users.id = stakes.owner
  WHERE stakes.message IS NOT NULL;
