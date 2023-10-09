DROP TYPE IF EXISTS AddOption CASCADE;
CREATE TYPE AddOption AS (
  slug TEXT,
  "name" TEXT,
  image TEXT,
  "order" INTEGER
);

DROP TYPE IF EXISTS EditOption CASCADE;
CREATE TYPE EditOption AS (
  slug TEXT,
  "version" INTEGER,
  "name" TEXT,
  image TEXT,
  remove_image BOOLEAN,
  "order" INTEGER
);

DROP TYPE IF EXISTS RemoveOption CASCADE;
CREATE TYPE RemoveOption AS (
  slug TEXT,
  "version" INTEGER
);

DROP TYPE IF EXISTS AddLockMoment CASCADE;
CREATE TYPE AddLockMoment AS (
  slug TEXT,
  "name" TEXT,
  "order" INTEGER
);

DROP TYPE IF EXISTS EditLockMoment CASCADE;
CREATE TYPE EditLockMoment AS (
  slug TEXT,
  "version" INTEGER,
  "name" TEXT,
  "order" INTEGER
);

DROP TYPE IF EXISTS RemoveLockMoment CASCADE;
CREATE TYPE RemoveLockMoment AS (
  slug TEXT,
  "version" INTEGER
);

DROP FUNCTION IF EXISTS notify CASCADE;
CREATE FUNCTION notify () RETURNS TRIGGER LANGUAGE plpgsql AS $$
  BEGIN
    PERFORM pg_notify('user_notifications_' || NEW."for"::TEXT, NEW.id::TEXT);
    RETURN NEW;
  END;
$$;
DROP TRIGGER IF EXISTS notify_user ON notifications;
CREATE OR REPLACE TRIGGER notify_user
  AFTER INSERT ON notifications FOR EACH ROW EXECUTE FUNCTION notify();

DROP FUNCTION IF EXISTS validate_manage_permissions CASCADE;
CREATE FUNCTION validate_manage_permissions (
  credential JSONB,
  session_lifetime INTERVAL
) RETURNS users.id%TYPE LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    can_manage_permissions BOOLEAN;
  BEGIN
    user_id = validate_credentials(credential, session_lifetime);
    SELECT INTO can_manage_permissions
      general_permissions.manage_permissions
    FROM general_permissions
    WHERE general_permissions."user" = user_id;
    IF can_manage_permissions THEN
      RETURN user_id;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'FRBDN',
        MESSAGE = 'Missing permission: manage permissions.';
    END IF;
  END;
$$;

DROP FUNCTION IF EXISTS validate_manage_games CASCADE;
CREATE FUNCTION validate_manage_games (
  credential JSONB,
  session_lifetime INTERVAL
) RETURNS users.id%TYPE LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    can_manage_games BOOLEAN;
  BEGIN
    user_id = validate_credentials(credential, session_lifetime);
    SELECT INTO can_manage_games
      general_permissions.manage_games
    FROM general_permissions
    WHERE general_permissions."user" = user_id;
    IF can_manage_games THEN
      RETURN user_id;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'FRBDN',
        MESSAGE = 'Missing permission: manage games.';
    END IF;
  END;
$$;

DROP FUNCTION IF EXISTS validate_upload CASCADE;
CREATE FUNCTION validate_upload (
  credential JSONB,
  session_lifetime INTERVAL
) RETURNS users.id%TYPE LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    can_upload BOOLEAN;
  BEGIN
    user_id = validate_credentials(credential, session_lifetime);
    WITH
      general AS (
        SELECT
          (
            bool_or(manage_games) OR
            bool_or(manage_bets) OR
            bool_or(manage_gacha)
          ) AS any_permission
        FROM general_permissions
        WHERE "user" = user_id
        GROUP BY "user"
      ),
      specific AS (
        SELECT
          bool_or(manage_bets) AS any_permission
        FROM specific_permissions
        WHERE "user" = user_id
        GROUP BY "user"
      )
    SELECT INTO can_upload
      (general.any_permission OR specific.any_permission) AS can_upload
    FROM
      general CROSS JOIN specific;
    IF can_upload THEN
      RETURN user_id;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'FRBDN',
        MESSAGE = 'Missing permission: upload.';
    END IF;
  END;
$$;

DROP FUNCTION IF EXISTS validate_manage_bets CASCADE;
CREATE FUNCTION validate_manage_bets (
  credential JSONB,
  session_lifetime INTERVAL,
  target_game games.slug%TYPE
) RETURNS users.id%TYPE LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    can_manage_bets BOOLEAN;
  BEGIN
    user_id = validate_credentials(credential, session_lifetime);
    SELECT INTO can_manage_bets
      per_game_permissions.manage_bets
    FROM
      per_game_permissions INNER JOIN
      games ON per_game_permissions.game = games.id
    WHERE
      per_game_permissions."user" = user_id AND
      games.slug = target_game;
    IF can_manage_bets THEN
      RETURN user_id;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'FRBDN',
        MESSAGE = 'Missing permission: manage bets for specific game.';
    END IF;
  END;
$$;

DROP FUNCTION IF EXISTS validate_credentials CASCADE;
CREATE FUNCTION validate_credentials (
  credential JSONB,
  session_lifetime INTERVAL
) RETURNS users.id%TYPE LANGUAGE plpgsql AS $$
  BEGIN
    CASE credential->>'credential'
      WHEN 'user-session' THEN
        DECLARE
          user_id users.id%TYPE;
          started sessions.started%TYPE;
        BEGIN
          SELECT INTO user_id, started
            users.id,
            sessions.started
          FROM sessions INNER JOIN users ON sessions."user" = users.id
          WHERE
            users.slug = credential->>'user' AND
            sessions.session = credential->>'session';
          IF user_id IS NOT NULL THEN
            IF now() < (started + session_lifetime) THEN
              RETURN user_id;
            ELSE
              RAISE EXCEPTION USING
                ERRCODE = 'UAUTH',
                MESSAGE = 'Expired session.';
            END IF;
          ELSE
            RAISE EXCEPTION USING
              ERRCODE = 'UAUTH',
              MESSAGE = 'Invalid session.';
          END IF;
        END;
      WHEN 'external-service' THEN
        DECLARE
          user_id users.id%TYPE;
        BEGIN
          SELECT users.id
          INTO user_id
          FROM users
          WHERE
            users.slug = credential->>'actingAs';
          IF user_id IS NOT NULL THEN
            RETURN user_id;
          ELSE
            RAISE EXCEPTION USING
              ERRCODE = 'UAUTH',
              MESSAGE = 'Invalid service credential.';
          END IF;
        END;
      ELSE
        RAISE EXCEPTION USING
          ERRCODE = 'UAUTH',
          MESSAGE = 'Invalid credential type.';
    END CASE;
  END;
$$;

DROP FUNCTION IF EXISTS acting_as_slug CASCADE;
CREATE FUNCTION acting_as_slug (
  credential JSONB
) RETURNS users.slug%TYPE LANGUAGE plpgsql AS $$
  BEGIN
    CASE credential->>'credential'
      WHEN 'user-session' THEN
        RETURN credential->>'user';
      WHEN 'external-service' THEN
        RETURN credential->>'actingAs';
      ELSE
        RAISE EXCEPTION USING
          ERRCODE = 'UAUTH',
          MESSAGE = 'Invalid credential type.';
    END CASE;
  END;
$$;

DROP FUNCTION IF EXISTS add_bet CASCADE;
CREATE FUNCTION add_bet (
  credential JSONB,
  session_lifetime INTERVAL,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE,
  given_name bets.name%TYPE,
  given_description bets.description%TYPE,
  given_spoiler bets.spoiler%TYPE,
  given_lock_moment_slug lock_moments.slug%TYPE,
  "options" AddOption[]
) RETURNS bets LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    game_id games.id%TYPE;
    author_id users.id%TYPE;
    lock_moment_id lock_moments.id%TYPE;
    bet bets%ROWTYPE;
  BEGIN
    SELECT validate_manage_bets(credential, session_lifetime, game_slug) INTO user_id;

    SELECT id INTO game_id FROM games WHERE games.slug = game_slug;
    IF game_id is NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Game not found.';
    END IF;

    SELECT id INTO author_id FROM users WHERE users.id = user_id;
    IF author_id is NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Author not found.';
    END IF;

    SELECT id INTO lock_moment_id FROM lock_moments
    WHERE lock_moments.game = game_id AND lock_moments.slug = given_lock_moment_slug;
    IF lock_moment_id is NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Lock moment not found.';
    END IF;

    BEGIN
      INSERT INTO bets (game, slug, "name", description, spoiler, lock_moment, progress, author) VALUES (
        game_id,
        bet_slug,
        given_name,
        given_description,
        given_spoiler,
        lock_moment_id,
        'Voting'::BetProgress,
        author_id
      ) RETURNING bets.* INTO bet;
    EXCEPTION
      WHEN UNIQUE_VIOLATION THEN
        RAISE EXCEPTION USING
          ERRCODE = 'BDREQ',
          MESSAGE = 'Bet slug already exists.';
    END;

    BEGIN
      INSERT INTO options (bet, slug, name, image, "order")
        SELECT bet.id, ingest.slug, ingest.name, ingest.image, row_number() OVER ()
        FROM unnest(options) AS ingest(slug, "name", image, "order");
    EXCEPTION
      WHEN UNIQUE_VIOLATION THEN
        RAISE EXCEPTION USING
          ERRCODE = 'BDREQ',
          MESSAGE = 'Option slug already exists.';
    END;

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'AddBet',
        'author_id', user_id,
        'bet_slug', bet.slug,
        'bet_name', bet.name
      )
    );

    RETURN bet;
  END;
$$;

DROP FUNCTION IF EXISTS add_game CASCADE;
CREATE FUNCTION add_game (
  credential JSONB,
  session_lifetime INTERVAL,
  game_slug games.slug%TYPE,
  given_name games.name%TYPE,
  given_cover games.cover%TYPE,
  given_started games.started%TYPE,
  given_finished games.finished%TYPE,
  given_order games."order"%TYPE
) RETURNS games LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    game games%ROWTYPE;
  BEGIN 
    SELECT validate_manage_games(credential, session_lifetime) INTO user_id;

    BEGIN
      INSERT INTO games (slug, name, cover, started, finished, "order")
      VALUES (
        game_slug,
        given_name,
        given_cover,
        given_started,
        given_finished,
        given_order
      ) RETURNING games.* INTO game;
    EXCEPTION
      WHEN UNIQUE_VIOLATION THEN
        RAISE EXCEPTION USING
          ERRCODE = 'BDREQ',
          MESSAGE = 'Game slug already exists.';
    END;

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'AddGame',
        'author_id', user_id,
        'game_slug', game.slug,
        'game_name', game.name
      )
    );

    RETURN game;
  END;
$$;

DROP FUNCTION IF EXISTS edit_lock_moments CASCADE;
CREATE FUNCTION edit_lock_moments (
  credential JSONB,
  session_lifetime INTERVAL,
  game_slug games.slug%TYPE,
  remove RemoveLockMoment[],
  edit EditLockMoment[],
  add AddLockMoment[]
) RETURNS SETOF lock_moments LANGUAGE plpgsql AS $$
DECLARE
  game_id games.id%TYPE;
  count INT;
BEGIN
  PERFORM validate_manage_bets(credential, session_lifetime, game_slug);

  SELECT id INTO game_id FROM games WHERE slug = game_slug;
  IF game_id is NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = 'NTFND',
      MESSAGE = 'Game not found.';
  END IF;

  SET CONSTRAINTS unique_lock_moment_order_in_game DEFERRED;

  IF remove IS NOT NULL THEN
    WITH
      deleted AS (
        DELETE FROM lock_moments
        USING unnest(remove) AS removes(slug, version)
        WHERE
          lock_moments.slug = removes.slug AND
          lock_moments.version = removes.version AND
          lock_moments.game = game_id
        RETURNING 1
      )
    SELECT count(*) INTO count FROM deleted;
    IF count <> array_length(remove, 1) THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Lock moment to remove not found or wrong version.';
    END IF;
  END IF;

  DECLARE
    violation TEXT;
  BEGIN
    IF edit IS NOT NULL THEN
      UPDATE lock_moments SET
        version = edits.version + 1,
        name = coalesce(edits."name", lock_moments.name),
        "order" = coalesce(edits."order", lock_moments."order")
      FROM unnest(edit) AS edits(slug, version, "name", "order")
      WHERE
        lock_moments.game = game_id AND
        lock_moments.slug = edits.slug;
    END IF;

    IF add IS NOT NULL THEN
      INSERT INTO lock_moments (slug, game, name, "order")
      SELECT
        adds.slug AS slug,
        game_id AS game,
        adds."name" AS name,
        adds."order" AS "order"
      FROM unnest(add) AS adds(slug, "name", "order");
    END IF;

    SET CONSTRAINTS unique_lock_moment_order_in_game IMMEDIATE;
  EXCEPTION
    WHEN UNIQUE_VIOLATION THEN
      GET STACKED DIAGNOSTICS violation := CONSTRAINT_NAME;
      IF violation = 'unique_lock_moment_slug_in_game' THEN
        RAISE EXCEPTION USING
          ERRCODE = 'BDREQ',
          MESSAGE = 'Lock moment slug already exists in game.';
      ELSEIF violation = 'unique_lock_moment_order_in_game' THEN
        RAISE EXCEPTION USING
          ERRCODE = 'BDREQ',
          MESSAGE = 'Lock moment order already exists in game.';
      ELSE
        RAISE;
      END IF;
  END;

  RETURN QUERY SELECT * FROM lock_moments WHERE lock_moments.game = game_id;
END;
$$;

DROP FUNCTION IF EXISTS default_avatar CASCADE;
CREATE FUNCTION default_avatar (
  discord_id users.discord_id%TYPE,
  discriminator users.discriminator%TYPE
) RETURNS avatars.default_index%TYPE IMMUTABLE LANGUAGE plpgsql AS $$
BEGIN
  RETURN CASE 
    WHEN discriminator IS NULL THEN
      (((discord_id::BIGINT) >> 22) % 6)::INT
    ELSE
      ((discriminator::INT) % 5)::INT
  END;
END;
$$;

DROP FUNCTION IF EXISTS discord_avatar_url CASCADE;
CREATE FUNCTION discord_avatar_url (
  discord_id users.discord_id%TYPE,
  discriminator users.discriminator%TYPE,
  avatar_hash avatars.hash%TYPE
) RETURNS avatars.url%TYPE IMMUTABLE LANGUAGE plpgsql AS $$
BEGIN
  RETURN CASE
    WHEN avatar_hash IS NOT NULL THEN
      'https://cdn.discordapp.com/avatars/' || discord_id || '/' || avatar_hash || '.webp'
    ELSE
      'https://cdn.discordapp.com/embed/avatars/' || default_avatar(discord_id, discriminator) || '.png'
    END;
END;
$$;

DROP FUNCTION IF EXISTS bankrupt CASCADE;
CREATE FUNCTION bankrupt (
  credential JSONB,
  session_lifetime INTERVAL,
  initial_balance users.balance%TYPE
) RETURNS users LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    result users%ROWTYPE;
    old_balance users.balance%TYPE;
  BEGIN
    SELECT validate_credentials(credential, session_lifetime) INTO user_id;

    DELETE FROM stakes
    USING
      options INNER JOIN
      bets ON options.bet = bets.id AND is_active(bets.progress)
    WHERE
      stakes.owner = user_id AND
      options.id = stakes.option;

    SELECT balance INTO old_balance FROM users WHERE id = user_id;

    UPDATE users
    SET balance = initial_balance
    WHERE id = user_id
    RETURNING users.* INTO result;

    INSERT INTO notifications ("for", notification) VALUES (
      result.id,
      jsonb_build_object(
        'type', 'Gifted',
        'amount', initial_balance,
        'reason', 'Bankruptcy'
      )
    );

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'Bankrupt',
        'user_id', user_id,
        'old_balance', old_balance,
        'new_balance', result.balance
      )
    );

    RETURN result;
  END;
$$;

DROP FUNCTION IF EXISTS cancel_bet CASCADE;
CREATE FUNCTION cancel_bet (
  credential JSONB,
  session_lifetime INTERVAL,
  old_version bets.version%TYPE,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE,
  reason TEXT
) RETURNS bets LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    cancelled_bet bets%ROWTYPE;
  BEGIN
    SELECT validate_manage_bets(credential, session_lifetime, game_slug) INTO user_id;

    WITH
      refunds AS (
        UPDATE users SET
          balance = users.balance + stakes.amount
        FROM stakes INNER JOIN
          options ON stakes.option = options.id INNER JOIN
          bets ON options.bet = bets.id AND bets.slug = bet_slug INNER JOIN
          games ON bets.game = games.id AND games.slug = game_slug
        WHERE
          stakes.owner = users.id
        RETURNING
          users.id AS "user",
          stakes.option AS option,
          stakes.amount AS amount
      ),
      notifyUsers AS (
        INSERT INTO notifications ("for", notification)
        SELECT
          refunds."user",
          jsonb_build_object(
            'type', 'Refunded',
            'game_slug', games.slug,
            'game_name', games.name,
            'bet_slug', bets.slug,
            'bet_name', bets.name,
            'option_slug', options.slug,
            'option_name', options.name,
            'reason', 'BetCancelled',
            'amount', refunds.amount
          )
        FROM (
          refunds LEFT JOIN
            games ON games.slug = game_slug LEFT JOIN
            bets ON bets.slug = bet_slug LEFT JOIN
            options ON options.id = option
        )
     )
    UPDATE bets SET
      version = old_version + 1,
      progress = 'Cancelled'::BetProgress,
      resolved = now(),
      cancelled_reason = reason
    FROM games
    WHERE
      bets.game = games.id AND
      bets.slug = bet_slug AND
      games.slug = game_slug AND
      is_active(bets.progress)
    RETURNING bets.* INTO cancelled_bet;

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'CancelBet',
        'user_id', user_id,
        'game_slug', game_slug,
        'bet_slug', bet_slug,
        'reason', reason
      )
    );

    RETURN cancelled_bet;
  END;
$$;

DROP FUNCTION IF EXISTS change_stake CASCADE;
CREATE FUNCTION change_stake (
  min_stake stakes.amount%TYPE,
  notable_stake stakes.amount%TYPE,
  max_bet_while_in_debt stakes.amount%TYPE,
  credential JSONB,
  session_lifetime INTERVAL,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE,
  option_slug options.slug%TYPE,
  staked stakes.amount%TYPE,
  given_message stakes.message%TYPE
) RETURNS INTEGER LANGUAGE plpgsql AS $$
  BEGIN
    PERFORM withdraw_stake(
      credential,
      session_lifetime,
      game_slug,
      bet_slug,
      option_slug
    );
    RETURN new_stake(
      min_stake,
      notable_stake,
      max_bet_while_in_debt,
      credential,
      session_lifetime,
      game_slug,
      bet_slug,
      option_slug,
      staked,
      given_message
    );
  END;
$$;

DROP FUNCTION IF EXISTS complete_bet CASCADE;
CREATE FUNCTION complete_bet (
  credential JSONB,
  session_lifetime INTERVAL,
  scrap_per_roll users.scrap%TYPE,
  win_bet_roll_reward users.rolls%TYPE,
  lose_bet_scrap_reward users.scrap%TYPE,
  old_version bets.version%TYPE,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE,
  winners TEXT[] -- options.slug%TYPE[]
) RETURNS bets LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    completed_bet bets%ROWTYPE;
  BEGIN
    SELECT validate_manage_bets(credential, session_lifetime, game_slug) INTO user_id;

    WITH
      staked AS (
        SELECT
          options.id AS option,
          sum(stakes.amount) AS total,
          (options.slug = ANY(winners)) AS is_winner
        FROM stakes INNER JOIN
          options ON stakes.option = options.id INNER JOIN
          bets ON options.bet = bets.id INNER JOIN
          games ON bets.game = games.id
        WHERE games.slug = game_slug AND bets.slug = bet_slug
        GROUP BY (options.id, options.slug)
      ),
      pot AS (
        SELECT
          option,
          is_winner,
          CASE
            WHEN is_winner THEN
              coalesce(sum(total) FILTER (WHERE NOT is_winner) OVER (), 0) / (count(*) FILTER (WHERE is_winner) OVER ())
            ELSE
              0
          END AS amount
        FROM staked
      ),
      payouts AS (
        SELECT
          stakes.id AS stake,
          stakes.owner AS "user",
          stakes.option,
          stakes.amount AS staked,
          pot.is_winner,
          CASE pot.is_winner
            WHEN TRUE THEN
              stakes.amount + (pot.amount / (sum(stakes.amount) OVER same_option) * stakes.amount)::INT
            ELSE
              NULL
          END AS amount,
          CASE WHEN pot.is_winner THEN win_bet_roll_reward ELSE 0 END AS rolls,
          CASE WHEN pot.is_winner THEN 0 ELSE lose_bet_scrap_reward END AS scrap
        FROM stakes INNER JOIN pot ON stakes.option = pot.option
        WINDOW same_option AS (PARTITION BY stakes.option)
      ),
      update_winners AS (
        UPDATE users SET
          balance = CASE WHEN payouts.amount IS NOT NULL THEN users.balance + payouts.amount ELSE users.balance END,
          rolls = users.rolls + payouts.rolls + ((users.scrap + payouts.scrap) / scrap_per_roll),
          scrap = ((users.scrap + payouts.scrap) % scrap_per_roll)
        FROM payouts WHERE payouts."user" = users.id
      ),
      update_stakes AS (
        UPDATE stakes SET
          payout = payouts.amount,
          gacha_payout_rolls = payouts.rolls,
          gacha_payout_scrap = payouts.scrap
        FROM payouts
        WHERE
          payouts.option = stakes.option AND
          payouts."user" = stakes.owner
      ),
      update_options AS (
        UPDATE options SET
          version = version + 1,
          won = TRUE
        WHERE
          slug = ANY(winners)
      ),
      notify_users AS (
        INSERT INTO notifications ("for", notification)
        SELECT
          stakes.owner,
          jsonb_build_object(
            'type', 'BetFinished',
            'game_slug', games.slug,
            'game_name', games.name,
            'bet_slug', bets.slug,
            'bet_name', bets.name,
            'option_slug', options.slug,
            'option_name', options.name,
            'result', CASE
              WHEN payouts.is_winner THEN 'Win'
              ELSE 'Loss'
            END,
            'amount', coalesce(payouts.amount, 0),
            'gacha_amount', jsonb_build_object(
              'rolls', coalesce(payouts.rolls, 0),
              'scrap', coalesce(payouts.scrap, 0)
            )
          )
        FROM
          payouts INNER JOIN
          stakes ON payouts.stake = stakes.id INNER JOIN
          options ON stakes.option = options.id INNER JOIN
          bets ON options.bet = bets.id INNER JOIN
          games ON bets.game = games.id
      )
      UPDATE bets SET
        version = old_version + 1,
        resolved = now(),
        progress = 'Complete'
      FROM games
      WHERE bets.game = games.id AND games.slug = game_slug AND bets.slug = bet_slug AND is_active(bets.progress)
      RETURNING bets.* INTO completed_bet;

      INSERT INTO audit_logs (event) VALUES (
        jsonb_build_object(
          'event', 'CompleteBet',
          'user_id', user_id,
          'game_slug', game_slug,
          'bet_slug', bet_slug,
          'winners', to_jsonb(winners)
        )
      );

    RETURN completed_bet;
  END;
$$;

DROP FUNCTION IF EXISTS edit_bet CASCADE;
CREATE FUNCTION edit_bet (
  credential JSONB,
  session_lifetime INTERVAL,
  old_version bets.version%TYPE,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE,
  given_name bets.name%TYPE,
  given_description bets.description%TYPE,
  given_spoiler bets.spoiler%TYPE,
  given_lock_moment_slug lock_moments.slug%TYPE,
  remove_options RemoveOption[],
  edit_options EditOption[],
  add_options AddOption[]
) RETURNS bets LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    edited_bet bets%ROWTYPE;
  BEGIN
    SELECT validate_manage_bets(credential, session_lifetime, game_slug) INTO user_id;

    SET CONSTRAINTS options_order DEFERRED;

    UPDATE bets SET
      version = old_version + 1,
      name = coalesce(given_name, bets.name),
      description = coalesce(given_description, bets.description),
      spoiler = coalesce(given_spoiler, bets.spoiler),
      lock_moment = lock_moments.id
    FROM
      games INNER JOIN lock_moments ON games.id = lock_moments.game
    WHERE
      bets.game = games.id AND
      games.slug = game_slug AND
      bets.slug = bet_slug AND (
        (given_lock_moment_slug IS NOT NULL AND lock_moments.slug = given_lock_moment_slug) OR
        (given_lock_moment_slug IS NULL AND bets.lock_moment = lock_moments.id)
      )
    RETURNING bets.* INTO edited_bet;

    WITH
      deleted_options AS (
        DELETE FROM options
        USING
          unnest(remove_options) AS removes(slug, version) CROSS JOIN
            bets INNER JOIN
            games ON bets.game = games.id
        WHERE
          options.bet = bets.id AND
          options.slug = removes.slug AND
          options.version = removes.version AND
          bets.slug = bet_slug AND
          games.slug = game_slug
        RETURNING options.*
      ),
      invalid_stakes AS (
        DELETE FROM stakes
        USING
          deleted_options AS options INNER JOIN
            bets ON options.bet = bets.id INNER JOIN
            games ON bets.game = games.id
        WHERE
          stakes.option = options.id AND
          bets.slug = bet_slug AND
          games.slug = game_slug
        RETURNING
          stakes.amount,
          stakes.owner,
          options.slug AS option_slug,
          options.name AS option_name,
          games.slug AS game_slug,
          games.name AS game_name,
          bets.slug AS bet_slug,
          bets.name AS bet_name
      ),
      refunds AS (
        UPDATE users SET
          balance = users.balance + stakes.amount
        FROM invalid_stakes AS stakes WHERE stakes.owner = users.id
      )
    INSERT INTO notifications ("for", notification)
    SELECT
      refunds.owner,
      jsonb_build_object(
        'type', 'Refunded',
        'game_slug', refunds.game_slug,
        'game_name', refunds.game_name,
        'bet_slug', refunds.bet_slug,
        'bet_name', refunds.bet_name,
        'option_slug', refunds.option_slug,
        'option_name', refunds.option_name,
        'reason', 'OptionRemoved',
        'amount', refunds.amount
      )
    FROM invalid_stakes AS refunds;

    UPDATE options SET
      version = edits.version + 1,
      name = coalesce(edits.name, options.name),
      image = CASE
        WHEN edits.remove_image THEN NULL
        ELSE coalesce(edits.image, options.image)
      END,
      "order" = coalesce(edits."order", options."order")
    FROM
      unnest(edit_options) AS edits(slug, version, "name", image, remove_image, "order") INNER JOIN
        bets ON bets.slug = bet_slug INNER JOIN
        games ON bets.game = games.id AND games.slug = game_slug
    WHERE options.bet = bets.id AND options.slug = edits.slug;

    INSERT INTO options (bet, slug, name, image, "order")
    SELECT bets.id, adds.slug, adds.name, adds.image, adds."order"
    FROM
      unnest(add_options) AS adds(slug, "name", image, "order") INNER JOIN
        bets ON bets.slug = bet_slug INNER JOIN
        games ON bets.game = games.id AND games.slug = game_slug;

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'EditBet',
        'user_id', user_id,
        'game_slug', game_slug,
        'bet_slug', bet_slug,
        'from_version', old_version
      )
    );

    RETURN edited_bet;
  END;
$$;

DROP FUNCTION IF EXISTS edit_game CASCADE;
CREATE FUNCTION edit_game (
  credential JSONB,
  session_lifetime INTERVAL,
  game_slug games.slug%TYPE,
  old_version games.version%TYPE,
  new_name games.name%TYPE,
  new_cover games.cover%TYPE,
  new_started games.started%TYPE,
  clear_started BOOLEAN,
  new_finished games.finished%TYPE,
  clear_finished BOOLEAN,
  new_order games.order%TYPE,
  clear_order BOOLEAN
) RETURNS games LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    result games%ROWTYPE;
  BEGIN
    SELECT validate_manage_games(credential, session_lifetime) INTO user_id;
    UPDATE games SET
      version = old_version + 1,
      name = coalesce(new_name, name),
      cover = coalesce(new_cover, cover),
      started = CASE WHEN clear_started THEN NULL ELSE coalesce(new_started, started) END,
      finished = CASE WHEN clear_finished THEN NULL ELSE coalesce(new_finished, finished) END,
      "order" = CASE WHEN clear_order THEN NULL ELSE coalesce(new_order, "order") END
    WHERE games.slug = game_slug
    RETURNING games.* INTO result;
    IF FOUND THEN
      INSERT INTO audit_logs (event) VALUES (
        jsonb_build_object(
          'event', 'EditGame',
          'user_id', user_id,
          'game_slug', game_slug,
          'from_version', old_version
        )
      );
      RETURN result;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Game not found.';
    END IF;
  END;
$$;

DROP FUNCTION IF EXISTS get_notification CASCADE;
CREATE FUNCTION get_notification (
  credential JSONB,
  session_lifetime INTERVAL,
  notification_id notifications.id%TYPE
) RETURNS notifications LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    notification notifications%ROWTYPE;
  BEGIN
    SELECT validate_credentials(credential, session_lifetime) INTO user_id;

    SELECT notifications.* INTO notification
    FROM notifications
    WHERE notifications."for" = user_id AND notifications.id = notification_id;

    RETURN notification;
  END;
$$;

DROP FUNCTION IF EXISTS get_notifications CASCADE;
CREATE FUNCTION get_notifications (
  credential JSONB,
  session_lifetime INTERVAL,
  include_read BOOLEAN
) RETURNS SETOF notifications LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
  BEGIN
    SELECT validate_credentials(credential, session_lifetime) INTO user_id;

    RETURN QUERY
      SELECT notifications.*
      FROM notifications
      WHERE notifications."for" = user_id AND (include_read OR notifications.read = FALSE);
  END;
$$;

DROP FUNCTION IF EXISTS login CASCADE;
CREATE FUNCTION login (
  given_discord_id users.discord_id%TYPE,
  given_session sessions.session%TYPE,
  given_username users.username%TYPE,
  given_display_name users.display_name%TYPE,
  given_discriminator users.discriminator%TYPE,
  given_avatar_hash avatars.hash%TYPE,
  given_access_token sessions.access_token%TYPE,
  given_refresh_token sessions.refresh_token%TYPE,
  discord_expires_in INTERVAL,
  initial_balance users.balance%TYPE
) RETURNS sessions LANGUAGE plpgsql AS $$
DECLARE
  new_user BOOLEAN;
  avatar_id avatars.id%TYPE;
  user_id users.id%TYPE;
  user_slug users.slug%TYPE;
  default_avatar avatars.default_index%TYPE;
  session sessions%ROWTYPE;
BEGIN
  default_avatar = CASE WHEN given_avatar_hash IS NULL THEN default_avatar(given_discord_id, given_discriminator) ELSE NULL END;

  INSERT INTO
    avatars (discord_user, hash, default_index, url)
  VALUES (
    given_discord_id,
    given_avatar_hash,
    default_avatar,
    discord_avatar_url(given_discord_id, given_discriminator, given_avatar_hash)
  ) ON CONFLICT DO NOTHING;

  SELECT id INTO avatar_id FROM avatars WHERE
    (default_avatar IS NULL AND discord_user = given_discord_id AND hash = given_avatar_hash) OR
    (given_avatar_hash IS NULL AND default_index = default_avatar);

  INSERT INTO
    users (discord_id, username, display_name, discriminator, avatar, balance)
  VALUES (
    given_discord_id,
    given_username,
    given_display_name,
    given_discriminator,
    avatar_id,
    initial_balance
  )
  ON CONFLICT ON CONSTRAINT unique_discord_id DO UPDATE SET
    username = excluded.username,
    display_name = excluded.display_name,
    discriminator = excluded.discriminator,
    avatar = excluded.avatar
  RETURNING (xmax = 0) INTO new_user;

  SELECT id, slug INTO user_id, user_slug FROM users WHERE discord_id = given_discord_id;

  INSERT INTO sessions ("user", session, access_token, refresh_token, discord_expires)
  VALUES (
    user_id,
    given_session,
    given_access_token,
    given_refresh_token,
    (now() + discord_expires_in)
  ) RETURNING sessions.* INTO session;

  IF new_user THEN
    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'NewUser',
        'user_slug', user_slug,
        'discord_id', given_discord_id,
        'balance', initial_balance
      )
    );
    INSERT INTO notifications ("for", notification) VALUES(
     user_id,
     jsonb_build_object(
       'type', 'Gifted',
       'amount', initial_balance,
       'reason', 'AccountCreated'
     )
    );
  END IF;

  RETURN session;
END;
$$;

DROP FUNCTION IF EXISTS new_stake CASCADE;
CREATE FUNCTION new_stake (
  min_stake stakes.amount%TYPE,
  notable_stake stakes.amount%TYPE,
  max_bet_while_in_debt stakes.amount%TYPE,
  credential JSONB,
  session_lifetime INTERVAL,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE,
  option_slug options.slug%TYPE,
  staked stakes.amount%TYPE,
  given_message stakes.message%TYPE
) RETURNS INTEGER LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    bet_is_voting BOOLEAN;
    new_balance users.balance%TYPE;
  BEGIN
    SELECT validate_credentials(credential, session_lifetime) INTO user_id;

    IF staked < min_stake THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Staked amount must be at least the configured minimum stake (' || min_stake || ').';
    END IF;

    IF given_message IS NOT NULL AND staked < notable_stake THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Not a notable stake (' || notable_stake || '), can’t leave a message.';
    END IF;

    SELECT bets.progress = 'Voting'::BetProgress INTO bet_is_voting
    FROM bets INNER JOIN games ON bets.game = games.id AND games.slug = game_slug
    WHERE bets.slug = bet_slug;

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
          INSERT INTO stakes (option, owner, amount, message)
          SELECT options.id, user_id, staked, given_message
          FROM
            options INNER JOIN
            bets ON options.bet = bets.id AND bets.slug = bet_slug INNER JOIN
            games ON bets.game = games.id AND games.slug = game_slug
          WHERE options.slug = option_slug
          RETURNING stakes.owner AS "user", stakes.amount
        )
      UPDATE users
      SET balance = balance - stake.amount
      FROM stake
      WHERE stake.user = users.id
      RETURNING balance INTO new_balance;
    EXCEPTION
      WHEN UNIQUE_VIOLATION THEN
        RAISE EXCEPTION USING
          ERRCODE = 'BDREQ',
          MESSAGE = 'You already have a bet on this option.';
    END;

    IF new_balance < 0 AND staked > max_bet_while_in_debt THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Can’t place a bet of this size while in debt.';
    END IF;

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'NewStake',
        'user_id', user_id,
        'game_slug', game_slug,
        'bet_slug', bet_slug,
        'option_slug', option_slug,
        'staked', staked,
        'message', given_message,
        'new_balance', new_balance
      )
    );

    RETURN new_balance;
  END;
$$;

DROP FUNCTION IF EXISTS revert_cancel_bet CASCADE;
CREATE FUNCTION revert_cancel_bet (
  credential JSONB,
  session_lifetime INTERVAL,
  old_version bets.version%TYPE,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE
) RETURNS bets LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    bet_id bets.id%TYPE;
    reverted_bet bets%ROWTYPE;
  BEGIN
    SELECT validate_manage_bets(credential, session_lifetime, game_slug) INTO user_id;

    SELECT bets.id
    INTO bet_id
    FROM bets INNER JOIN games ON bets.game = games.id
    WHERE games.slug = game_slug AND bets.slug = bet_slug AND bets.progress = 'Cancelled';
    IF NOT FOUND THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Bet must exist and be cancelled to revert cancellation.';
    END IF;

    UPDATE users
    SET balance = users.balance - stakes.amount
    FROM stakes INNER JOIN options ON stakes.option = options.id AND options.bet = bet_id
    WHERE stakes.owner = users.id;

    INSERT INTO notifications ("for", notification)
    SELECT
      stakes.owner,
      jsonb_build_object(
        'type', 'BetReverted',
        'game_slug', games.slug,
        'game_name', games.name,
        'bet_slug', bets.slug,
        'bet_name', bets.name,
        'option_slug', options.slug,
        'option_name', options.name,
        'reverted', bets.progress,
        'amount', coalesce(-stakes.amount, 0)
      )
    FROM
      stakes LEFT JOIN
        options ON stakes.option = options.id INNER JOIN
        bets ON options.bet = bets.id AND bets.id = bet_id INNER JOIN
        games ON bets.game = games.id;

    UPDATE bets SET
      version = old_version + 1,
      resolved = NULL,
      cancelled_reason = NULL,
      progress = 'Locked'::BetProgress
    WHERE id = bet_id
    RETURNING bets.* INTO reverted_bet;

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'RevertCancelBet',
        'user_id', user_id,
        'game_slug', game_slug,
        'bet_slug', bet_slug
      )
    );

    RETURN reverted_bet;
  END;
$$;

DROP FUNCTION IF EXISTS revert_complete_bet CASCADE;
CREATE FUNCTION revert_complete_bet (
  credential JSONB,
  session_lifetime INTERVAL,
  old_version bets.version%TYPE,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE
) RETURNS bets LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    bet_id bets.id%TYPE;
    reverted_bet bets%ROWTYPE;
  BEGIN
    SELECT validate_manage_bets(credential, session_lifetime, game_slug) INTO user_id;

    SELECT bets.id
    INTO bet_id
    FROM bets INNER JOIN games ON bets.game = games.id
    WHERE games.slug = game_slug AND bets.slug = bet_slug AND bets.progress = 'Complete';
    IF NOT FOUND THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Bet must be complete to revert completion.';
    END IF;

    UPDATE users SET
      balance = users.balance - coalesce(stakes.payout, 0),
      rolls = greatest(users.rolls - stakes.gacha_payout_rolls, 0),
      scrap = greatest(users.scrap - stakes.gacha_payout_scrap, 0)
    FROM stakes INNER JOIN options ON stakes.option = options.id AND options.bet = bet_id
    WHERE stakes.owner = users.id;

    INSERT INTO notifications ("for", notification)
    SELECT
      stakes.owner,
      jsonb_build_object(
        'type', 'BetReverted',
        'game_slug', games.slug,
        'game_name', games.name,
        'bet_slug', bets.slug,
        'bet_name', bets.name,
        'option_slug', options.slug,
        'option_name', options.name,
        'reverted', bets.progress,
        'amount', -coalesce(stakes.payout, 0),
        'gacha_amount', jsonb_build_object(
          'rolls', -coalesce(stakes.gacha_payout_rolls, 0),
          'scrap', -coalesce(stakes.gacha_payout_scrap, 0)
        )
      )
    FROM
      stakes LEFT JOIN
        options ON stakes.option = options.id INNER JOIN
        bets ON options.bet = bets.id AND bets.id = bet_id INNER JOIN
        games ON bets.game = games.id;

    UPDATE stakes SET
      payout = NULL,
      gacha_payout_scrap = NULL,
      gacha_payout_rolls = NULL
    FROM
      options
    WHERE
      options.bet = bet_id AND
      stakes.option = options.id;

    UPDATE options SET
      version = version + 1,
      won = FALSE
    WHERE
      bet = bet_id AND
      won = TRUE;

    UPDATE bets SET
      version = old_version + 1,
      resolved = NULL,
      progress = 'Locked'::BetProgress
    WHERE id = bet_id
    RETURNING bets.* INTO reverted_bet;

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'RevertCompleteBet',
        'user_id', user_id,
        'game_slug', game_slug,
        'bet_slug', bet_slug
      )
    );

    RETURN reverted_bet;
  END;
$$;

DROP FUNCTION IF EXISTS set_bet_locked CASCADE;
CREATE FUNCTION set_bet_locked (
  credential JSONB,
  session_lifetime INTERVAL,
  old_version bets.version%TYPE,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE,
  target_lock_state BOOLEAN
) RETURNS bets LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    target BetProgress;
    expected BetProgress;
    bet bets%ROWTYPE;
  BEGIN
    SELECT validate_manage_bets(credential, session_lifetime, game_slug) INTO user_id;

    IF (target_lock_state) THEN
      target = 'Locked'::BetProgress;
      expected = 'Voting'::BetProgress;
    ELSE
      target = 'Voting'::BetProgress;
      expected = 'Locked'::BetProgress;
    END IF;

    UPDATE bets SET
      version = old_version + 1,
      progress = target
    FROM games
    WHERE
      bets.game = games.id AND
      games.slug = game_slug AND
      bets.slug = bet_slug AND
      bets.progress = expected
    RETURNING bets.* INTO bet;

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'SetBetLocked',
        'user_id', user_id,
        'game_slug', game_slug,
        'bet_slug', bet_slug,
        'locked', target_lock_state
      )
    );

    RETURN bet;
  END;
$$;

DROP FUNCTION IF EXISTS set_permissions CASCADE;
CREATE FUNCTION set_permissions (
  credential JSONB,
  session_lifetime INTERVAL,
  user_slug users.slug%TYPE,
  game_slug games.slug%TYPE,
  set_manage_games BOOLEAN,
  set_manage_permissions BOOLEAN,
  set_manage_gacha BOOLEAN,
  set_manage_bets BOOLEAN
) RETURNS users LANGUAGE plpgsql AS $$
  DECLARE
    editor_id users.id%TYPE;
    result_user users%ROWTYPE;
  BEGIN
    SELECT validate_manage_permissions(credential, session_lifetime) INTO editor_id;

    IF game_slug IS NOT NULL THEN
      INSERT INTO specific_permissions (game, "user", manage_bets)
      SELECT
        games.id AS game,
        users.id AS "user",
        set_manage_bets AS manage_bets
      FROM
        users INNER JOIN
        games ON users.slug = user_slug AND games.slug = game_slug
      ON CONFLICT ON CONSTRAINT one_specific_permissions_per_game_per_user DO UPDATE SET
        manage_bets = coalesce(set_manage_bets, specific_permissions.manage_bets);
    ELSE
      UPDATE general_permissions
      SET
        manage_games = coalesce(set_manage_games, general_permissions.manage_games),
        manage_permissions = coalesce(set_manage_permissions, general_permissions.manage_permissions),
        manage_gacha = coalesce(set_manage_gacha, general_permissions.manage_gacha),
        manage_bets = coalesce(set_manage_bets, general_permissions.manage_bets)
      FROM users
      WHERE general_permissions.user = users.id AND users.slug = user_slug;
    END IF;

    SELECT users.* INTO result_user FROM users WHERE users.slug = user_slug;

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'SetPermission',
        'editor_id', editor_id,
        'user_slug', user_slug,
        'game_slug', game_slug,
        'manage_games', set_manage_games,
        'manage_permissions', set_manage_permissions,
        'manage_gacha', set_manage_gacha,
        'manage_bets', set_manage_bets
      )
    );

    RETURN result_user;
  END;
$$;

DROP FUNCTION IF EXISTS set_read CASCADE;
CREATE FUNCTION set_read (
  credential JSONB,
  session_lifetime INTERVAL,
  notification_id notifications.id%TYPE
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
  BEGIN
    SELECT validate_credentials(credential, session_lifetime) INTO user_id;

    UPDATE notifications
    SET read = TRUE
    WHERE notifications."for" = user_id AND notifications.id = notification_id;

    IF FOUND THEN
      RETURN TRUE;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Notification not found.';
    END IF;
  END;
$$;

DROP FUNCTION IF EXISTS withdraw_stake CASCADE;
CREATE FUNCTION withdraw_stake (
  credential JSONB,
  session_lifetime INTERVAL,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE,
  option_slug options.slug%TYPE
) RETURNS INTEGER LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    bet_is_voting BOOLEAN;
    new_balance users.balance%TYPE;
  BEGIN
    SELECT validate_credentials(credential, session_lifetime) INTO user_id;

    SELECT bets.progress = 'Voting'::BetProgress INTO bet_is_voting
    FROM bets INNER JOIN games ON bets.game = games.id
    WHERE games.slug = game_slug AND bets.slug = bet_slug;

    IF NOT FOUND THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Bet not found.';
    END IF;

    IF NOT bet_is_voting THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Bet not accepting stake modifications.';
    END IF;

    WITH
      stake AS (
        DELETE FROM stakes
          USING
            options INNER JOIN
            bets ON bets.slug = bet_slug AND options.bet = bets.id INNER JOIN
            games ON games.slug = game_slug AND bets.game = games.id
          WHERE
            options.slug = option_slug AND
            stakes.owner = user_id AND
            stakes.option = options.id AND
            stakes.message IS NULL
          RETURNING stakes.owner AS "user", stakes.amount
      )
    UPDATE users SET balance = balance + stake.amount FROM stake WHERE stake.user = users.id
    RETURNING balance INTO new_balance;

    IF FOUND THEN
      INSERT INTO audit_logs (event) VALUES (
        jsonb_build_object(
          'event', 'WithdrawStake',
          'user_id', user_id,
          'game_slug', game_slug,
          'bet_slug', bet_slug,
          'option_slug', option_slug,
          'new_balance', new_balance
        )
      );
      RETURN new_balance;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Modifiable stake not found.';
    END IF;
  END;
$$;
