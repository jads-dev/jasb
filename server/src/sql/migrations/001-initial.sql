CREATE SCHEMA jasb;

CREATE DOMAIN jasb.Unit AS BOOLEAN CHECK (value = TRUE);

CREATE TYPE jasb.BetProgress AS ENUM (
  'Voting',
  'Locked',
  'Complete',
  'Cancelled'
);

CREATE FUNCTION jasb.is_active(progress BetProgress) RETURNS BOOLEAN AS $$
  SELECT progress IN ('Voting'::BetProgress, 'Locked'::BetProgress)
$$ LANGUAGE SQL;

CREATE FUNCTION jasb.is_hidden(progress BetProgress) RETURNS BOOLEAN AS $$
  SELECT progress = 'Cancelled'::BetProgress
$$ LANGUAGE SQL;

CREATE FUNCTION jasb.update_version() RETURNS TRIGGER AS $$
  BEGIN
    IF NEW.version != (OLD.version + 1) THEN
      RAISE EXCEPTION USING
        ERRCODE = 'CONFL',
        MESSAGE = 'Version mismatch (expected ' || OLD.version + 1 || ', got ' || NEW.version || ').';
    END IF;
    NEW.modified := NOW();
    RETURN NEW;
  END
$$ LANGUAGE PLPGSQL;

CREATE TYPE jasb.GameProgress AS ENUM (
  'Future',
  'Current',
  'Finished'
);

CREATE TABLE jasb.instance (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  version INTEGER NOT NULL,
  migrated_from_firestore BOOLEAN DEFAULT FALSE,
  highlander Unit NOT NULL DEFAULT TRUE,

  UNIQUE (highlander)
);

CREATE TABLE jasb.games (
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  cover TEXT NOT NULL,
  igdb_id TEXT NOT NULL,
  added TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started DATE,
  finished DATE,

  version INT NOT NULL DEFAULT 0,
  modified TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  progress GameProgress NOT NULL GENERATED ALWAYS AS (CASE
    WHEN started IS NULL AND FINISHED IS NULL THEN 'Future'::GameProgress
    WHEN started IS NOT NULL AND FINISHED IS NULL THEN 'Current'::GameProgress
    WHEN started IS NOT NULL AND FINISHED IS NOT NULL THEN 'Finished'::GameProgress
  END) STORED,

  PRIMARY KEY (id),
  CONSTRAINT started_if_finished CHECK (NOT (started IS NULL AND finished IS NOT NULL))
);

CREATE TRIGGER update_game_version BEFORE UPDATE
  ON jasb.games FOR EACH ROW
  EXECUTE PROCEDURE jasb.update_version();

CREATE TABLE jasb.users (
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  discriminator TEXT NOT NULL,
  avatar TEXT,

  created TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  admin BOOLEAN NOT NULL DEFAULT FALSE,

  balance INT NOT NULL,

  PRIMARY KEY (id)
);

CREATE TABLE jasb.per_game_permissions (
  game TEXT NOT NULL,
  "user" TEXT NOT NULL,
  manage_bets BOOLEAN NOT NULL,

  PRIMARY KEY (game, "user"),
  CONSTRAINT fk_game FOREIGN KEY (game) REFERENCES games(id) ON DELETE CASCADE,
  CONSTRAINT fk_user FOREIGN KEY ("user") REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE jasb.sessions (
  "user" TEXT NOT NULL,
  session TEXT NOT NULL,
  started TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  access_token TEXT NOT NULL,
  refresh_token TEXT NOT NULL,
  discord_expires TIMESTAMPTZ NOT NULL,

  PRIMARY KEY ("user", session),
  CONSTRAINT fk_user FOREIGN KEY ("user") REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE jasb.bets (
  game TEXT NOT NULL,
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  spoiler BOOLEAN NOT NULL,
  locks_when TEXT NOT NULL,
  progress BetProgress NOT NULL,
  cancelled_reason TEXT,
  resolved TIMESTAMPTZ,

  created TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  version INT NOT NULL DEFAULT 0,
  modified TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  by TEXT NOT NULL,

  PRIMARY KEY (game, id),
  CONSTRAINT fk_game FOREIGN KEY (game) REFERENCES games(id) ON DELETE CASCADE,
  CONSTRAINT fk_by FOREIGN KEY (by) REFERENCES users(id),
  CONSTRAINT resolved_when_necessary CHECK (
    (resolved IS NULL AND progress IN ('Voting', 'Locked')) OR
    (resolved IS NOT NULL AND progress IN ('Complete', 'Cancelled'))
  ),
  CONSTRAINT reason_when_cancelled CHECK (
    (cancelled_reason IS NOT NULL AND progress = 'Cancelled') OR
    (cancelled_reason IS NULL AND progress != 'Cancelled')
  )
);

CREATE TRIGGER update_bet_version BEFORE UPDATE
  ON jasb.bets FOR EACH ROW
  EXECUTE PROCEDURE jasb.update_version();

CREATE TABLE jasb.options (
  game TEXT NOT NULL,
  bet TEXT NOT NULL,
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  image TEXT,
  won BOOLEAN NOT NULL DEFAULT FALSE,
  "order" INT NOT NULL,

  created TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  version INT NOT NULL DEFAULT 0,
  modified TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (game, bet, id),
  CONSTRAINT options_order UNIQUE (game, bet, "order") DEFERRABLE INITIALLY IMMEDIATE,
  CONSTRAINT fk_game FOREIGN KEY (game) REFERENCES games(id) ON DELETE CASCADE,
  CONSTRAINT fk_bet FOREIGN KEY (game, bet) REFERENCES bets(game, id) ON DELETE CASCADE
);

CREATE TRIGGER update_option_version BEFORE UPDATE
  ON jasb.options FOR EACH ROW
  EXECUTE PROCEDURE jasb.update_version();

CREATE TABLE jasb.stakes (
  game TEXT NOT NULL,
  bet TEXT NOT NULL,
  option TEXT NOT NULL,
  owner TEXT NOT NULL,
  made_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  amount INT NOT NULL,
  message TEXT,

  PRIMARY KEY (game, bet, option, owner),
  CONSTRAINT fk_game FOREIGN KEY (game) REFERENCES games(id) ON DELETE CASCADE,
  CONSTRAINT fk_bet FOREIGN KEY (game, bet) REFERENCES bets(game, id) ON DELETE CASCADE,
  CONSTRAINT fk_option FOREIGN KEY (game, bet, option) REFERENCES options(game, bet, id) ON DELETE CASCADE,
  CONSTRAINT fk_owner FOREIGN KEY (owner) REFERENCES users(id),
  CONSTRAINT positive_amount CHECK (amount > 0)
);

CREATE TYPE jasb.UserAndStake AS (
  "user" jasb.users,
  stake jasb.stakes
);

CREATE TYPE OptionAndStakes AS (
  option jasb.options,
  stakes jasb.UserAndStake[]
);

CREATE VIEW jasb.game_bet_stats AS
  SELECT
    games.id AS game,
    COUNT(bets.id)::INT AS bets
  FROM games INNER JOIN bets ON games.id = bets.game
  GROUP BY games.id;

CREATE VIEW jasb.game_stake_stats AS
  SELECT
    games.id AS game,
    SUM(stakes.amount)::INT AS staked
  FROM games INNER JOIN stakes ON games.id = stakes.game
  GROUP BY games.id;

CREATE VIEW jasb.game_mods AS
  SELECT
    games.id AS game,
    COALESCE(
      ARRAY_AGG(
        (users.*)::jasb.users
      ) FILTER (WHERE users.id IS NOT NULL),
      '{}'
    ) AS mods
  FROM
    games
      LEFT JOIN per_game_permissions as perm ON games.id = perm.game AND manage_bets
      LEFT JOIN users ON perm."user" = users.id
  GROUP BY games.id;

CREATE VIEW jasb.feed_new_bets AS
  SELECT
    games.id AS game,
    bets.id AS bet,
    bets.created AS time,
    JSONB_BUILD_OBJECT(
      'type', 'NewBet',
      'game', JSONB_BUILD_OBJECT('id', games.id, 'name', games.name),
      'bet', JSONB_BUILD_OBJECT('id', bets.id, 'name', bets.name),
      'spoiler', bets.spoiler
    ) AS item
  FROM bets INNER JOIN games ON games.id = bets.game
  WHERE bets.progress != 'Cancelled';

CREATE VIEW jasb.bet_stats AS
  WITH
    options AS (
      SELECT
        options.game,
        options.bet,
        COALESCE(
          ARRAY_AGG((options.*)::jasb.options ORDER BY options."order"),
          '{}'
        ) AS winners
      FROM jasb.options
      WHERE options.won
      GROUP BY (options.game, options.bet)
    ),
    stakes AS (
      SELECT
        options.game,
        options.bet,
        COALESCE(MAX(stakes.amount) FILTER (WHERE (options.won)), 0) AS biggest_winning_stake,
        COALESCE(SUM(stakes.amount)::INT, 0) AS total_staked,
        COALESCE(SUM(stakes.amount) FILTER (WHERE (options.won))::INT, 0) AS winning_staked,
        COUNT((stakes.option, stakes.owner)) FILTER (WHERE stakes.owner IS NOT NULL AND options.won)::INT AS winning_stakes,
        COUNT(stakes.owner) FILTER (WHERE (options.won))::INT AS winning_users
      FROM jasb.options INNER JOIN jasb.stakes ON
        options.game = stakes.game AND
        options.bet = stakes.bet AND
        options.id = stakes.option
      GROUP BY (options.game, options.bet)
    ),
    biggest_stakes_with_user AS (
      SELECT
        stakes.game,
        stakes.bet,
        stakes.owner,
        MIN(stakes.made_at) AS made_at
      FROM jasb.stakes
        INNER JOIN jasb.options ON
          options.game = stakes.game AND
          options.bet = stakes.bet AND
          options.id = stakes.option AND
          won = true
        INNER JOIN stakes AS stake_stats ON stakes.game = stake_stats.game AND stakes.bet = stake_stats.bet
      WHERE stakes.amount = stake_stats.biggest_winning_stake
      GROUP BY (stakes.game, stakes.bet, stakes.owner)
    ),
    users AS (
      SELECT
        stakes.game,
        stakes.bet,
        COALESCE(
          ARRAY_AGG(
            (users.*)::jasb.users
            ORDER BY stakes.made_at
          ) FILTER (WHERE users.id IS NOT NULL),
          '{}'
        ) AS top_winners
        FROM
          biggest_stakes_with_user AS stakes
          INNER JOIN jasb.users ON users.id = stakes.owner
          INNER JOIN jasb.options ON stakes.game = options.game AND stakes.bet = options.bet
        WHERE options.won
        GROUP BY (stakes.game, stakes.bet)
    )
    SELECT
      bets.game,
      bets.id,
      options.winners,
      users.top_winners,
      stakes.biggest_winning_stake,
      stakes.winning_staked,
      stakes.total_staked,
      stakes.winning_stakes,
      stakes.winning_users
    FROM jasb.bets
      LEFT JOIN options ON options.game = bets.game AND options.bet = bets.id
      LEFT JOIN stakes ON stakes.game = bets.game AND stakes.bet = bets.id
      LEFT JOIN users ON users.game = bets.game AND users.bet = bets.id
    WHERE bets.progress = 'Complete'::BetProgress
    GROUP BY (
      bets.game,
      bets.id,
      options.winners,
      users.top_winners,
      stakes.biggest_winning_stake,
      stakes.winning_staked,
      stakes.total_staked,
      stakes.winning_stakes,
      stakes.winning_users
     );

CREATE VIEW jasb.feed_bet_complete AS
  SELECT
    games.id AS game,
    bets.id AS bet,
    bets.resolved AS time,
    JSONB_BUILD_OBJECT(
      'type', 'BetComplete',
      'game', JSONB_BUILD_OBJECT('id', games.id, 'name', games.name),
      'bet', JSONB_BUILD_OBJECT('id', bets.id, 'name', bets.name),
      'spoiler', bets.spoiler,
      'winners', (SELECT JSONB_AGG(JSONB_BUILD_OBJECT('id', id, 'name', name)) FROM UNNEST(bet_stats.winners)),
      'highlighted', JSONB_BUILD_OBJECT(
        'winners', TO_JSONB(bet_stats.top_winners),
        'amount', CASE
          WHEN bet_stats.winning_staked = 0 THEN 0
          ELSE ((bet_stats.total_staked::float / bet_stats.winning_staked::float) * bet_stats.biggest_winning_stake)::int
        END
      ),
      'totalReturn', bet_stats.total_staked,
      'winningStakes', bet_stats.winning_stakes
    ) AS item
  FROM bets
    INNER JOIN games ON games.id = bets.game
    INNER JOIN bet_stats ON bet_stats.game = bets.game AND bet_stats.id = bets.id
  WHERE bets.progress = 'Complete';

CREATE VIEW jasb.feed_notable_stakes AS
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
        'avatar', users.avatar
      ),
      'message', stakes.message,
      'stake', stakes.amount
    ) AS item
  FROM stakes
     INNER JOIN games ON games.id = stakes.game
     INNER JOIN bets ON bets.id = stakes.bet AND bets.game = stakes.game
     INNER JOIN options ON
       options.game = stakes.game AND
       options.bet = stakes.bet AND
       options.id = stakes.option
     INNER JOIN users ON users.id = stakes.owner
  WHERE stakes.message IS NOT NULL;

CREATE VIEW jasb.feed AS
  SELECT * FROM feed_notable_stakes UNION ALL
  SELECT * FROM feed_bet_complete UNION ALL
  SELECT * FROM feed_new_bets;

CREATE VIEW jasb.stakes_by_option AS
  SELECT
    stakes.game,
    stakes.bet,
    stakes.option,
    ARRAY_AGG(
      ROW(
        (users.*)::jasb.users,
        (stakes.*)::jasb.stakes
      )::jasb.UserAndStake
      ORDER BY stakes.made_at
    ) FILTER (WHERE stakes.owner IS NOT NULL) AS stakes
  FROM jasb.stakes INNER JOIN jasb.users ON stakes.owner = users.id
  GROUP BY (stakes.game, stakes.bet, stakes.option);

CREATE VIEW jasb.options_by_bet AS
  SELECT
    options.game,
    options.bet,
    ARRAY_AGG(ROW(
      (options.*)::jasb.options,
      COALESCE(stakes.stakes, '{}')
    )::jasb.OptionAndStakes ORDER BY options.order) FILTER (WHERE options.id IS NOT NULL) AS options
  FROM jasb.options LEFT JOIN jasb.stakes_by_option as stakes ON
    options.game = stakes.game AND
    options.bet = stakes.bet AND
    options.id = stakes.option
  GROUP BY (options.game, options.bet);

CREATE VIEW jasb.users_with_stakes AS
  SELECT
    users.*,
    COALESCE(SUM(stakes.amount)::INT, 0) AS staked
  FROM users
    LEFT JOIN jasb.stakes ON users.id = stakes.owner
    INNER JOIN jasb.bets ON stakes.game = bets.game AND stakes.bet = bets.id
  WHERE is_active(bets.progress)
  GROUP BY users.id;

CREATE VIEW jasb.leaderboard AS
  SELECT
    users.*,
    (staked + balance) AS net_worth,
    RANK() OVER (
     ORDER BY (staked + balance) DESC
    ) rank
  FROM jasb.users_with_stakes AS users;

CREATE TABLE jasb.notifications (
  id INT GENERATED ALWAYS AS IDENTITY,
  "for" TEXT NOT NULL,
  happened TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  notification JSONB NOT NULL,
  read BOOLEAN NOT NULL DEFAULT FALSE,

  PRIMARY KEY (id),
  CONSTRAINT fk_for FOREIGN KEY ("for") REFERENCES users(id)
);

CREATE TABLE jasb.audit_logs (
  id INT GENERATED ALWAYS AS IDENTITY,
  "user" TEXT NOT NULL,
  happened TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  event JSONB NOT NULL,

  PRIMARY KEY (id),
  CONSTRAINT fk_user FOREIGN KEY ("user") REFERENCES users(id)
);

CREATE VIEW jasb.permissions AS
  SELECT
    users.id AS "user",
    games.id AS game,
    (per_game_permissions.manage_bets OR users.admin) AS manage_bets
  FROM
    (jasb.users CROSS JOIN jasb.games) LEFT OUTER JOIN
    jasb.per_game_permissions ON
      users.id = per_game_permissions."user" AND
      games.id = per_game_permissions.game;

INSERT INTO jasb.instance(version) VALUES (5);
