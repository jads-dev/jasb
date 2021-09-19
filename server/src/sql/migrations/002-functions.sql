CREATE OR REPLACE FUNCTION jasb.validate_session(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL
)
  RETURNS BOOLEAN
  LANGUAGE PLPGSQL
AS $$
  DECLARE
    valid_session BOOLEAN;
  BEGIN
    SELECT
      TRUE INTO valid_session
    FROM jasb.sessions
    WHERE
      "user" = user_id AND
      session = given_session AND
      NOW() < (started + session_lifetime);
    valid_session := COALESCE(valid_session, FALSE);
    IF valid_session THEN
      RETURN TRUE;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'UAUTH',
        MESSAGE = 'Invalid session.';
    END IF;
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.validate_admin(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL
)
  RETURNS BOOLEAN
  LANGUAGE PLPGSQL
AS $$
  DECLARE
    valid_session BOOLEAN;
    is_admin BOOLEAN;
  BEGIN
    SELECT
      TRUE,
      users.admin
    INTO
      valid_session,
      is_admin
    FROM jasb.sessions INNER JOIN jasb.users ON sessions."user" = users.id
    WHERE
      sessions."user" = user_id AND
      sessions.session = given_session AND
      NOW() < (sessions.started + session_lifetime);
    valid_session := COALESCE(valid_session, FALSE);
    IF valid_session THEN
      IF is_admin THEN
        RETURN TRUE;
      ELSE
        RAISE EXCEPTION USING
          ERRCODE = 'FRBDN',
          MESSAGE = 'Must be an admin to perform this task.';
      END IF;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'UAUTH',
        MESSAGE = 'Invalid session.';
    END IF;
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.validate_manage_bets(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  target_game games.id%TYPE
)
  RETURNS BOOLEAN
  LANGUAGE PLPGSQL
AS $$
  DECLARE
    valid_session BOOLEAN;
    can_manage_bets BOOLEAN;
  BEGIN
    SELECT
      TRUE,
      permissions.manage_bets
    INTO
      valid_session,
      can_manage_bets
    FROM jasb.sessions LEFT JOIN
      jasb.permissions ON sessions."user" = permissions."user" AND permissions.game = target_game
    WHERE
      sessions."user" = user_id AND
      sessions.session = given_session AND
      NOW() < (sessions.started + session_lifetime);
    valid_session := COALESCE(valid_session, FALSE);
    IF valid_session THEN
      IF can_manage_bets THEN
        RETURN TRUE;
      ELSE
        RAISE EXCEPTION USING
          ERRCODE = 'FRBDN',
          MESSAGE = 'Missing permission: manage bets.';
      END IF;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'UAUTH',
        MESSAGE = 'Invalid session.';
    END IF;
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.validate_admin_or_mod(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL
)
  RETURNS BOOLEAN
  LANGUAGE PLPGSQL
AS $$
  DECLARE
    valid_session BOOLEAN;
    is_admin_or_mod BOOLEAN;
  BEGIN
    SELECT
      TRUE,
      (users.admin OR bool_or(jasb.per_game_permissions.manage_bets))
    INTO
      valid_session,
      is_admin_or_mod
    FROM jasb.sessions LEFT JOIN
      jasb.users ON sessions."user" = users.id LEFT JOIN
      jasb.per_game_permissions ON users.id = per_game_permissions."user"
    WHERE
      sessions."user" = user_id AND
      sessions.session = given_session AND
      NOW() < (sessions.started + session_lifetime)
    GROUP BY
      users.id;
    valid_session := COALESCE(valid_session, FALSE);
    IF valid_session THEN
      IF is_admin_or_mod THEN
        RETURN TRUE;
      ELSE
        RAISE EXCEPTION USING
          ERRCODE = 'FRBDN',
          MESSAGE = 'Must be admin or mod.';
      END IF;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'UAUTH',
        MESSAGE = 'Invalid session.';
    END IF;
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.bankrupt(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  initial_balance users.balance%TYPE
)
  RETURNS jasb.users
  LANGUAGE PLPGSQL
AS $$
  DECLARE
    result jasb.users;
  BEGIN
    PERFORM validate_session(user_id, given_session, session_lifetime);
    DELETE FROM jasb.stakes USING jasb.bets
      WHERE
        owner = user_id AND
        bets.id = stakes.bet AND
        is_active(bets.progress);
    UPDATE jasb.users SET
      balance = initial_balance
    WHERE id = user_id
    RETURNING * INTO result;
    INSERT INTO jasb.audit_logs ("user", event) VALUES (
      user_id,
      json_build_object(
        'event', 'Bankruptcy',
        'balance', initial_balance
      )
    );
    INSERT INTO jasb.notifications ("for", notification) VALUES (
      user_id,
      json_build_object(
        'type', 'Gifted',
        'balance', initial_balance,
        'reason', 'Bankruptcy'
      )
    );
    RETURN result;
  END;
$$;

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
      avatar = excluded.avatar
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
          'balance', initial_balance,
          'reason', 'AccountCreated'
        )
      );
    END IF;
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.add_game(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  game_id games.id%TYPE,
  given_name games.name%TYPE,
  given_cover games.cover%TYPE,
  given_igdb_id games.igdb_id%TYPE,
  given_started games.started%TYPE,
  given_finished games.finished%TYPE
)
  RETURNS SETOF jasb.games
  LANGUAGE PLPGSQL
AS $$
  BEGIN
    PERFORM validate_admin(user_id, given_session, session_lifetime);

    RETURN QUERY INSERT INTO jasb.games (id, name, cover, igdb_id, started, finished) VALUES (
      game_id,
      given_name,
      given_cover,
      given_igdb_id,
      given_started,
      given_finished
    ) RETURNING *;
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.edit_game(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  game_id games.id%TYPE,
  old_version games.version%TYPE,
  new_name games.name%TYPE DEFAULT NULL,
  new_cover games.cover%TYPE DEFAULT NULL,
  new_igdb_id games.igdb_id%TYPE DEFAULT NULL,
  new_started games.started%TYPE DEFAULT NULL,
  clear_started BOOLEAN DEFAULT FALSE,
  new_finished games.finished%TYPE DEFAULT NULL,
  clear_finished BOOLEAN DEFAULT FALSE
)
  RETURNS SETOF jasb.games
  LANGUAGE PLPGSQL
AS $$
  DECLARE
    result jasb.games;
  BEGIN
    PERFORM validate_admin(user_id, given_session, session_lifetime);
    UPDATE jasb.games SET
      version = old_version + 1,
      name = COALESCE(new_name, name),
      cover = COALESCE(new_cover, cover),
      igdb_id = COALESCE(new_igdb_id, igdb_id),
      started = CASE WHEN clear_started THEN NULL ELSE COALESCE(new_started, started) END,
      finished = CASE WHEN clear_finished THEN NULL ELSE COALESCE(new_finished, finished) END
    WHERE games.id = game_id
    RETURNING * INTO result;
    IF FOUND THEN
      RETURN NEXT result;
      RETURN;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Game not found.';
    END IF;
  END;
$$;

CREATE TYPE jasb.AddOption AS (
  id TEXT,
  name TEXT,
  image TEXT
);

CREATE OR REPLACE FUNCTION jasb.add_bet(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  game_id games.id%TYPE,
  bet_id bets.id%TYPE,
  given_name bets.name%TYPE,
  given_description bets.description%TYPE,
  given_spoiler bets.spoiler%TYPE,
  given_locks_when bets.locks_when%TYPE,
  options AddOption[]
)
  RETURNS SETOF jasb.bets
  LANGUAGE PLPGSQL
AS $$
  BEGIN
    PERFORM validate_manage_bets(user_id, given_session, session_lifetime, game_id);

    RETURN QUERY INSERT INTO jasb.bets (game, id, name, description, spoiler, locks_when, progress, by) VALUES (
      game_id,
      bet_id,
      given_name,
      given_description,
      given_spoiler,
      given_locks_when,
      'Voting'::BetProgress,
      user_id
    ) RETURNING *;

    INSERT INTO jasb.options (game, bet, id, name, image, "order")
      SELECT game_id, bet_id, ingest.id, ingest.name, ingest.image, ROW_NUMBER() OVER()
      FROM UNNEST(options) AS ingest;
  END;
$$;

CREATE TYPE jasb.EditOption AS (
  id TEXT,
  version INT,
  name TEXT,
  image TEXT,
  remove_image BOOLEAN,
  "order" INT
);

CREATE OR REPLACE FUNCTION jasb.edit_bet(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  old_version games.version%TYPE,
  game_id games.id%TYPE,
  bet_id bets.id%TYPE,
  given_name bets.name%TYPE,
  given_description bets.description%TYPE,
  given_spoiler bets.spoiler%TYPE,
  given_locks_when bets.locks_when%TYPE,
  remove_options TEXT[],
  edit_options EditOption[],
  add_options EditOption[]
)
  RETURNS SETOF jasb.bets
  LANGUAGE PLPGSQL
AS $$
  BEGIN
    PERFORM validate_manage_bets(user_id, given_session, session_lifetime, game_id);

    SET CONSTRAINTS jasb.options_order DEFERRED;

    RETURN QUERY UPDATE jasb.bets SET
      version = old_version + 1,
      name = COALESCE(given_name, bets.name),
      description = COALESCE(given_description, bets.description),
      spoiler = COALESCE(given_spoiler, bets.spoiler),
      locks_when = COALESCE(given_locks_when, bets.locks_when)
    WHERE game = game_id AND id = bet_id
    RETURNING *;

    WITH
      invalid_stakes AS (
        DELETE FROM jasb.stakes
        WHERE
          stakes.game = game_id AND
          stakes.bet = bet_id AND
          stakes.option = ANY(remove_options)
        RETURNING stakes.amount, stakes.option, stakes.owner
      ),
      deleted_options AS (
        DELETE FROM jasb.options
        WHERE game = game_id AND bet = bet_id AND id = ANY(remove_options)
        RETURNING id
      ),
      refunds AS (
        UPDATE jasb.users SET
          balance = users.balance + stakes.amount
        FROM invalid_stakes as stakes WHERE stakes.owner = users.id
      )
    INSERT INTO jasb.notifications ("for", notification) SELECT
      refunds.owner AS "for",
      json_build_object(
        'type', 'Refunded',
        'gameId', game_id,
        'gameName', games.name,
        'betId', bet_id,
        'betName', bets.name,
        'optionId', refunds.option,
        'optionName', options.name,
        'reason', 'OptionRemoved',
        'amount', refunds.amount
      ) AS notification
    FROM (
      invalid_stakes as refunds
      LEFT JOIN games ON games.id = game_id
      LEFT JOIN bets ON bets.game = game_id AND bets.id = bet_id
      LEFT JOIN options ON options.game = game_id AND options.bet = bet_id AND options.id = option
    );

    UPDATE jasb.options SET
      version = edits.version + 1,
      name = COALESCE(edits.name, options.name),
      image = CASE
        WHEN edits.remove_image THEN NULL
        ELSE COALESCE(edits.image, options.image)
      END,
      "order" = COALESCE(edits."order", options."order")
    FROM UNNEST(edit_options) AS edits
    WHERE options.game = game_id AND options.bet = bet_id AND options.id = edits.id;

    INSERT INTO jasb.options (game, bet, id, name, image, "order")
      SELECT game_id, bet_id, adds.id, adds.name, adds.image, adds."order"
      FROM UNNEST(add_options) AS adds;
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.set_bet_locked(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  old_version games.version%TYPE,
  game_id games.id%TYPE,
  bet_id bets.id%TYPE,
  target_lock_state BOOLEAN
)
  RETURNS SETOF jasb.bets
  LANGUAGE PLPGSQL
AS $$
  DECLARE
    target BetProgress;
    expected BetProgress;
  BEGIN
    PERFORM validate_manage_bets(user_id, given_session, session_lifetime, game_id);

    IF (target_lock_state) THEN
      target = 'Locked'::BetProgress;
      expected = 'Voting'::BetProgress;
    ELSE
      target = 'Voting'::BetProgress;
      expected = 'Locked'::BetProgress;
    END IF;

    RETURN QUERY UPDATE jasb.bets SET
      version = old_version + 1,
      progress = target
    WHERE
      bets.game = game_id AND
      bets.id = bet_id AND
      progress = expected
    RETURNING *;
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.complete_bet(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  old_version games.version%TYPE,
  game_id games.id%TYPE,
  bet_id bets.id%TYPE,
  winners TEXT[]
)
  RETURNS SETOF jasb.bets
  LANGUAGE PLPGSQL
AS $$
  BEGIN
    PERFORM validate_manage_bets(user_id, given_session, session_lifetime, game_id);

    RETURN QUERY WITH
      staked AS (
        SELECT
          sum(amount) AS total,
          sum(CASE WHEN option = ANY(winners) THEN amount ELSE 0 END) AS winning
        FROM jasb.stakes
        WHERE game = game_id AND bet = bet_id
        GROUP BY (game, bet)
      ),
      shares AS (
        SELECT
          stakes.owner AS "user",
          stakes.option,
          sum(stakes.amount) AS stake,
          CASE
            WHEN stakes.option = ANY(winners) THEN
              CASE
                WHEN sum(staked.winning) = 0 THEN 0
                ELSE ((sum(staked.total)::float / sum(staked.winning)::float) * sum(stakes.amount))::int
                END
            ELSE
              0
            END AS won
        FROM jasb.stakes CROSS JOIN staked
        WHERE game = game_id AND bet = bet_id
        GROUP BY (owner, option)
      ),
      winnings AS (
        SELECT
          "user",
          sum(won) AS won
        FROM shares
        GROUP BY "user"
      ),
      updateWinners AS (
        UPDATE jasb.users SET
          balance = users.balance + winnings.won
          FROM winnings WHERE winnings."user" = users.id
      ),
      updateOptions AS (
        UPDATE jasb.options SET
          version = version + 1,
          won = TRUE
        WHERE
          game = game_id AND
          bet = bet_id AND
          id = ANY(winners)
      ),
      notifyUsers AS (
        INSERT INTO jasb.notifications ("for", notification) SELECT
          shares."user" AS "for",
          json_build_object(
            'type', 'BetFinished',
            'gameId', game_id,
            'gameName', games.name,
            'betId', bet_id,
            'betName', bets.name,
            'optionId', shares.option,
            'optionName', options.name,
            'result', CASE
              WHEN options.id = ANY(winners) THEN 'Win'
              ELSE 'Loss'
            END,
            'amount', shares.won
          ) AS notification
        FROM (
          shares
          LEFT JOIN games ON games.id = game_id
          LEFT JOIN bets ON bets.game = game_id AND bets.id = bet_id
          LEFT JOIN options ON options.game = game_id AND options.bet = bet_id AND options.id = option
        )
      ),
      log AS (
        INSERT INTO jasb.audit_logs ("user", event) SELECT
          user_id,
          json_build_object(
            'event', 'Payout',
            'game', game_id,
            'bet', bet_id,
            'option', option,
            'stake', stake,
            'winnings', won
          )
        FROM shares
      )
    UPDATE jasb.bets SET
      version = old_version + 1,
      progress = 'Complete'::BetProgress,
      resolved = NOW()
    WHERE game = game_id AND id = bet_id AND progress IN ('Voting', 'Locked')
    RETURNING *;
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.cancel_bet(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  old_version games.version%TYPE,
  game_id games.id%TYPE,
  bet_id bets.id%TYPE,
  reason bets.cancelled_reason%TYPE
)
  RETURNS SETOF jasb.bets
  LANGUAGE PLPGSQL
AS $$
  BEGIN
    PERFORM validate_manage_bets(user_id, given_session, session_lifetime, game_id);

    RETURN QUERY WITH
      refunds AS (
        UPDATE jasb.users SET
          balance = users.balance + stakes.amount
        FROM stakes WHERE
          stakes.owner = users.id AND
          stakes.game = game_id AND
          stakes.bet = bet_id
        RETURNING
          users.id AS "user",
          stakes.option AS option,
          stakes.amount AS amount
      ),
      notifyUsers AS (
        INSERT INTO jasb.notifications ("for", notification) SELECT
          refunds."user" AS "for",
          json_build_object(
            'type', 'Refunded',
            'gameId', game_id,
            'gameName', games.name,
            'betId', bet_id,
            'betName', bets.name,
            'optionId', refunds.option,
            'optionName', options.name,
            'reason', 'BetCancelled',
            'amount', refunds.amount
          ) AS notification
        FROM (
          refunds
          LEFT JOIN games ON games.id = game_id
          LEFT JOIN bets ON bets.game = game_id AND bets.id = bet_id
          LEFT JOIN options ON options.game = game_id AND options.bet = bet_id AND options.id = option
        )
     )
    UPDATE jasb.bets SET
      version = old_version + 1,
      progress = 'Cancelled'::BetProgress,
      resolved = NOW(),
      cancelled_reason = reason
    WHERE game = game_id AND id = bet_id AND progress IN ('Voting', 'Locked')
    RETURNING *;
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.new_stake(
  notable_stake INT,
  max_bet_while_in_debt INT,
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  game_id games.id%TYPE,
  bet_id bets.id%TYPE,
  option_id options.id%TYPE,
  staked stakes.amount%TYPE,
  given_message stakes.message%TYPE
)
  RETURNS INT
  LANGUAGE PLPGSQL
AS $$
  DECLARE
    bet_is_voting BOOLEAN;
    new_balance INT;
  BEGIN
    PERFORM validate_session(user_id, given_session, session_lifetime);

    IF staked <= 0 THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Staked amount must be more than zero.';
    END IF;

    IF given_message IS NOT NULL AND staked < notable_stake THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Not a notable stake, can’t leave a message.';
    END IF;

    SELECT progress = 'Voting'::BetProgress INTO bet_is_voting
    FROM jasb.bets
    WHERE bets.game = game_id AND bets.id = bet_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Bet not found.';
    END IF;

    IF NOT BET_IS_VOTING THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Bet not accepting new stakes.';
    END IF;

    BEGIN
      WITH
        stake AS (
          INSERT INTO jasb.stakes (game, bet, option, owner, amount, message)
            VALUES (game_id, bet_id, option_id, user_id, staked, given_message)
          RETURNING owner AS "user", amount
        )
      UPDATE jasb.users
      SET balance = balance - stake.amount
      FROM stake
      WHERE stake.user = users.id
      RETURNING balance INTO new_balance;
    EXCEPTION
      WHEN UNIQUE_VIOLATION THEN
        RAISE EXCEPTION USING
          ERRCODE = 'BDREQ',
          MESSAGE = 'You already have a bet.';
    END;

    IF new_balance < 0 AND staked > max_bet_while_in_debt THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Can’t place a bet of this size while in debt.';
    END IF;

    RETURN new_balance;
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.withdraw_stake(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  game_id games.id%TYPE,
  bet_id bets.id%TYPE,
  option_id options.id%TYPE
)
  RETURNS INT
  LANGUAGE PLPGSQL
AS $$
  DECLARE
    bet_is_voting BOOLEAN;
    new_balance INT;
  BEGIN
    PERFORM validate_session(user_id, given_session, session_lifetime);

    SELECT progress = 'Voting'::BetProgress INTO bet_is_voting
    FROM jasb.bets
    WHERE bets.game = game_id AND bets.id = bet_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Bet not found.';
    END IF;

    IF NOT BET_IS_VOTING THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Bet not accepting stake modifications.';
    END IF;

    WITH
      stake AS (
        DELETE FROM jasb.stakes
          WHERE
            stakes.bet = bet_id AND
            stakes.game = game_id AND
            stakes.option = option_id AND
            stakes.owner = user_id AND
            stakes.message IS NULL
          RETURNING owner AS "user", amount
      )
    UPDATE jasb.users SET balance = balance + stake.amount FROM stake WHERE stake.user = users.id
    RETURNING balance INTO new_balance;

    IF FOUND THEN
      RETURN new_balance;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Modifiable stake not found.';
    END IF;
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.change_stake(
  notable_stake INT,
  max_bet_while_in_debt INT,
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  game_id games.id%TYPE,
  bet_id bets.id%TYPE,
  option_id options.id%TYPE,
  staked stakes.amount%TYPE,
  given_message stakes.message%TYPE
)
  RETURNS INT
  LANGUAGE PLPGSQL
AS $$
  BEGIN
    PERFORM jasb.withdraw_stake(
      user_id,
      given_session,
      session_lifetime,
      game_id,
      bet_id,
      option_id
    );
    RETURN jasb.new_stake(
    notable_stake,
      max_bet_while_in_debt,
      user_id,
      given_session,
      session_lifetime,
      game_id,
      bet_id,
      option_id,
      staked,
      given_message
    );
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.get_notifications(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  include_read BOOLEAN DEFAULT FALSE
)
  RETURNS SETOF jasb.notifications
  LANGUAGE PLPGSQL
AS $$
  BEGIN
    PERFORM validate_session(user_id, given_session, session_lifetime);

    RETURN QUERY
      SELECT *
      FROM jasb.notifications
      WHERE "for" = user_id AND (include_read OR read = FALSE)
      ORDER BY notifications.happened DESC;
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.set_read(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  notification_id INT
)
  RETURNS BOOLEAN
  LANGUAGE PLPGSQL
AS $$
  BEGIN
    PERFORM validate_session(user_id, given_session, session_lifetime);

    UPDATE jasb.notifications SET read = TRUE
    WHERE "for" = user_id AND id = notification_id;

    IF FOUND THEN
      RETURN TRUE;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Notification not found.';
    END IF;
  END;
$$;
