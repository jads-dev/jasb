DROP FUNCTION IF EXISTS validate_manage_permissions;

CREATE FUNCTION validate_manage_permissions (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
  DECLARE
    valid_session BOOLEAN;
    can_manage_permissions BOOLEAN;
  BEGIN
    SELECT
      TRUE AS valid_session,
      general_permissions.manage_permissions
    INTO
      valid_session,
      can_manage_permissions
    FROM sessions INNER JOIN
      users ON sessions."user" = users.id LEFT JOIN
      general_permissions ON users.id = general_permissions."user"
    WHERE
      user_slug = users.slug AND
      sessions.session = given_session AND
      (now() - session_lifetime) < sessions.started;
    valid_session := coalesce(valid_session, FALSE);
    IF valid_session THEN
      IF can_manage_permissions THEN
        RETURN TRUE;
      ELSE
        RAISE EXCEPTION USING
          ERRCODE = 'FRBDN',
          MESSAGE = 'Must be able to manage permissions to perform this task.';
      END IF;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'UAUTH',
        MESSAGE = 'Invalid session.';
    END IF;
  END;
$$;

DROP FUNCTION IF EXISTS validate_manage_games;

CREATE FUNCTION validate_manage_games (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
  DECLARE
    valid_session BOOLEAN;
    can_manage_games BOOLEAN;
  BEGIN
    SELECT
      TRUE AS valid_session,
      general_permissions.manage_games
    INTO
      valid_session,
      can_manage_games
    FROM sessions INNER JOIN
      users ON sessions."user" = users.id LEFT JOIN
      general_permissions ON users.id = general_permissions."user"
    WHERE
      user_slug = users.slug AND
      sessions.session = given_session AND
      (now() - session_lifetime) < sessions.started;
    valid_session := coalesce(valid_session, FALSE);
    IF valid_session THEN
      IF can_manage_games THEN
        RETURN TRUE;
      ELSE
        RAISE EXCEPTION USING
          ERRCODE = 'FRBDN',
          MESSAGE = 'Must be able to manage games to perform this task.';
      END IF;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'UAUTH',
        MESSAGE = 'Invalid session.';
    END IF;
  END;
$$;

DROP FUNCTION IF EXISTS validate_manage_games_or_bets;

CREATE FUNCTION validate_manage_games_or_bets (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
  DECLARE
    valid_session BOOLEAN;
    manage_games_or_bets BOOLEAN;
  BEGIN
    SELECT
      TRUE AS valid_session,
      (
        bool_or(general_permissions.manage_games) OR
        bool_or(general_permissions.manage_bets) OR
        bool_or(specific_permissions.manage_bets)
      ) AS manage_games_or_bets
    INTO
      valid_session,
      manage_games_or_bets
    FROM sessions LEFT JOIN
      users ON sessions."user" = users.id LEFT JOIN
      general_permissions ON users.id = general_permissions."user" LEFT JOIN
      specific_permissions ON users.id = specific_permissions."user"
    WHERE
      user_slug = users.slug AND
      sessions.session = given_session AND
      (now() - session_lifetime) < sessions.started
    GROUP BY
      users.id;
    valid_session := coalesce(valid_session, FALSE);
    IF valid_session THEN
      IF manage_games_or_bets THEN
        RETURN TRUE;
      ELSE
        RAISE EXCEPTION USING
          ERRCODE = 'FRBDN',
          MESSAGE = 'Must have permissions to manage games or bets.';
      END IF;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'UAUTH',
        MESSAGE = 'Invalid session.';
    END IF;
  END;
$$;

DROP FUNCTION IF EXISTS validate_manage_bets;

CREATE FUNCTION validate_manage_bets (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  target_game games.slug%TYPE
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
  DECLARE
    valid_session BOOLEAN;
    can_manage_bets BOOLEAN;
  BEGIN
    SELECT
      TRUE AS valid_session,
      per_game_permissions.manage_bets
    INTO
      valid_session,
      can_manage_bets
    FROM sessions INNER JOIN
      jasb.users ON sessions."user" = users.id LEFT JOIN
      (
        per_game_permissions INNER JOIN
        games ON per_game_permissions.game = games.id
      ) ON
        sessions."user" = per_game_permissions."user" AND
        games.slug = target_game
    WHERE
      users.slug = user_slug AND
      sessions.session = given_session AND
      (now() - session_lifetime) < sessions.started;
    valid_session := coalesce(valid_session, FALSE);
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

DROP FUNCTION IF EXISTS validate_session;

CREATE FUNCTION validate_session (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
  DECLARE
    valid_session BOOLEAN;
  BEGIN
    SELECT
      TRUE AS valid_session INTO valid_session
    FROM sessions INNER JOIN jasb.users ON sessions."user" = users.id
    WHERE
      users.slug = user_slug AND
      session = given_session AND
      (now() - session_lifetime) < started;
    valid_session := coalesce(valid_session, FALSE);
    IF valid_session THEN
      RETURN TRUE;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'UAUTH',
        MESSAGE = 'Invalid session.';
    END IF;
  END;
$$;

DROP FUNCTION IF EXISTS add_bet;

CREATE FUNCTION add_bet (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE,
  given_name bets.name%TYPE,
  given_description bets.description%TYPE,
  given_spoiler bets.spoiler%TYPE,
  given_lock_moment_slug lock_moments.slug%TYPE,
  "options" AddOption[]
) RETURNS SETOF bets LANGUAGE plpgsql AS $$
  DECLARE
    game_id games.id%TYPE;
    author_id users.id%TYPE;
    lock_moment_id lock_moments.id%TYPE;
    bet bets%ROWTYPE;
  BEGIN
    PERFORM validate_manage_bets(user_slug, given_session, session_lifetime, game_slug);

    SELECT id INTO game_id FROM games WHERE games.slug = game_slug;
    IF game_id is NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Game not found.';
    END IF;

    SELECT id INTO author_id FROM users WHERE users.slug = user_slug;
    IF author_id is NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Author not found.';
    END IF;

    SELECT id INTO lock_moment_id FROM lock_moments WHERE lock_moments.slug = given_lock_moment_slug;
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

    INSERT INTO jasb.audit_logs (event) VALUES (
      json_build_object(
        'event', 'AddBet',
        'author_slug', user_slug,
        'bet_slug', bet.slug,
        'bet_name', bet.name
      )
    );

    RETURN NEXT bet;
  END;
$$;

DROP FUNCTION IF EXISTS add_game;

CREATE FUNCTION add_game (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  game_slug games.slug%TYPE,
  given_name games.name%TYPE,
  given_cover games.cover%TYPE,
  given_started games.started%TYPE,
  given_finished games.finished%TYPE,
  given_order games."order"%TYPE
) RETURNS SETOF games LANGUAGE plpgsql AS $$
  DECLARE
    game games%ROWTYPE;
  BEGIN 
    PERFORM validate_manage_games(user_slug, given_session, session_lifetime);

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

    INSERT INTO jasb.audit_logs (event) VALUES (
      json_build_object(
        'event', 'AddGame',
        'author_slug', user_slug,
        'game_slug', game.slug,
        'game_name', game.name
      )
    );

    RETURN NEXT game;
  END;
$$;

DROP FUNCTION IF EXISTS edit_lock_moments;

CREATE FUNCTION edit_lock_moments (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
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
  PERFORM validate_manage_bets(user_slug, given_session, session_lifetime, game_slug);

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

DROP FUNCTION IF EXISTS default_avatar;

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

DROP FUNCTION IF EXISTS discord_avatar_url;

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

DROP FUNCTION IF EXISTS bankrupt;

CREATE FUNCTION bankrupt (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  initial_balance users.balance%TYPE
) RETURNS users LANGUAGE plpgsql AS $$
  DECLARE
    result users%ROWTYPE;
    old_balance users.balance%TYPE;
  BEGIN
    PERFORM validate_session(user_slug, given_session, session_lifetime);

    DELETE FROM stakes
    USING
      options INNER JOIN
      bets ON options.bet = bets.id AND is_active(bets.progress) INNER JOIN
      users ON users.slug = user_slug
    WHERE
      options.id = stakes.option;

    SELECT balance INTO old_balance FROM users WHERE slug = user_slug;

    UPDATE users
    SET balance = initial_balance
    WHERE slug = user_slug
    RETURNING users.* INTO result;

    INSERT INTO notifications ("for", notification) VALUES (
      result.id,
      json_build_object(
        'type', 'Gifted',
        'amount', initial_balance,
        'reason', 'Bankruptcy'
      )
    );

    INSERT INTO jasb.audit_logs (event) VALUES (
      json_build_object(
        'event', 'Bankrupt',
        'user_slug', user_slug,
        'old_balance', old_balance,
        'new_balance', result.balance
      )
    );

    RETURN result;
  END;
$$;

DROP FUNCTION IF EXISTS cancel_bet;

CREATE FUNCTION cancel_bet (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  old_version bets.version%TYPE,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE,
  reason TEXT
) RETURNS SETOF bets LANGUAGE plpgsql AS $$
  BEGIN
    PERFORM validate_manage_bets(user_slug, given_session, session_lifetime, game_slug);

    RETURN QUERY WITH
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
        INSERT INTO notifications ("for", notification) SELECT
          refunds."user" AS "for",
          json_build_object(
            'type', 'Refunded',
            'game_slug', games.slug,
            'game_name', games.name,
            'bet_slug', bets.slug,
            'bet_name', bets.name,
            'option_slug', options.slug,
            'option_name', options.name,
            'reason', 'BetCancelled',
            'amount', refunds.amount
          ) AS notification
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
    RETURNING bets.*;

    INSERT INTO jasb.audit_logs (event) VALUES (
      json_build_object(
        'event', 'CancelBet',
        'user_slug', user_slug,
        'game_slug', game_slug,
        'bet_slug', bet_slug,
        'reason', reason
      )
    );
  END;
$$;

DROP FUNCTION IF EXISTS change_stake;

CREATE FUNCTION change_stake (
  min_stake stakes.amount%TYPE,
  notable_stake stakes.amount%TYPE,
  max_bet_while_in_debt stakes.amount%TYPE,
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE,
  option_slug options.slug%TYPE,
  staked stakes.amount%TYPE,
  given_message stakes.message%TYPE
) RETURNS INTEGER LANGUAGE plpgsql AS $$
  BEGIN
    PERFORM withdraw_stake(
      user_slug,
      given_session,
      session_lifetime,
      game_slug,
      bet_slug,
      option_slug
    );
    RETURN new_stake(
      min_stake,
      notable_stake,
      max_bet_while_in_debt,
      user_slug,
      given_session,
      session_lifetime,
      game_slug,
      bet_slug,
      option_slug,
      staked,
      given_message
    );
  END;
$$;

DROP FUNCTION IF EXISTS complete_bet;

CREATE FUNCTION complete_bet (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  old_version bets.version%TYPE,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE,
  winners TEXT[] -- options.slug%TYPE[]
) RETURNS SETOF bets LANGUAGE plpgsql AS $$
  BEGIN
    PERFORM validate_manage_bets(user_slug, given_session, session_lifetime, game_slug);

    RETURN QUERY WITH
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
          END AS amount
        FROM stakes INNER JOIN pot ON stakes.option = pot.option
        WINDOW same_option AS (PARTITION BY stakes.option)
      ),
      updateWinners AS (
        UPDATE users SET
          balance = users.balance + payouts.amount
        FROM payouts WHERE payouts."user" = users.id AND payouts.amount IS NOT NULL
      ),
      updateStakes AS (
        UPDATE stakes SET
          payout = payouts.amount
        FROM payouts
        WHERE
          payouts.option = stakes.option AND
          payouts."user" = stakes.owner AND
          payouts.amount IS NOT NULL
      ),
      updateOptions AS (
        UPDATE options SET
          version = version + 1,
          won = TRUE
        WHERE
          slug = ANY(winners)
      ),
      notifyUsers AS (
        INSERT INTO notifications ("for", notification) SELECT
          stakes.owner AS "for",
          json_build_object(
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
            'amount', coalesce(payouts.amount, 0)
          ) AS notification
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
      RETURNING bets.*;

      INSERT INTO jasb.audit_logs (event) VALUES (
        json_build_object(
          'event', 'CompleteBet',
          'user_slug', user_slug,
          'game_slug', game_slug,
          'bet_slug', bet_slug,
          'winners', to_jsonb(winners)
        )
      );
  END;
$$;

DROP FUNCTION IF EXISTS edit_bet;

CREATE FUNCTION edit_bet (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
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
) RETURNS SETOF bets LANGUAGE plpgsql AS $$
  BEGIN
    PERFORM validate_manage_bets(user_slug, given_session, session_lifetime, game_slug);

    SET CONSTRAINTS options_order DEFERRED;

    RETURN QUERY UPDATE bets SET
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
    RETURNING bets.*;

    WITH
      invalid_stakes AS (
        DELETE FROM stakes
        USING
          options INNER JOIN
            unnest(remove_options) AS removes(slug, version) ON removes.slug = options.slug INNER JOIN
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
        RETURNING options.id
      ),
      refunds AS (
        UPDATE users SET
          balance = users.balance + stakes.amount
        FROM invalid_stakes AS stakes WHERE stakes.owner = users.id
      )
    INSERT INTO notifications ("for", notification) SELECT
      refunds.owner AS "for",
      json_build_object(
        'type', 'Refunded',
        'game_slug', refunds.game_slug,
        'game_name', refunds.game_name,
        'bet_slug', refunds.bet_slug,
        'bet_name', refunds.bet_name,
        'option_slug', refunds.option_slug,
        'option_name', refunds.option_name,
        'reason', 'OptionRemoved',
        'amount', refunds.amount
      ) AS notification
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

    INSERT INTO jasb.audit_logs (event) VALUES (
      json_build_object(
        'event', 'EditBet',
        'user_slug', user_slug,
        'game_slug', game_slug,
        'bet_slug', bet_slug,
        'from_version', old_version
      )
    );
  END;
$$;

DROP FUNCTION IF EXISTS edit_game;

CREATE FUNCTION edit_game (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
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
) RETURNS SETOF games LANGUAGE plpgsql AS $$
  DECLARE
    result games%ROWTYPE;
  BEGIN
    PERFORM validate_manage_games(user_slug, given_session, session_lifetime);
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
      INSERT INTO jasb.audit_logs (event) VALUES (
        json_build_object(
          'event', 'EditGame',
          'user_slug', user_slug,
          'game_slug', game_slug,
          'from_version', old_version
        )
      );
      RETURN NEXT result;
      RETURN;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Game not found.';
    END IF;

  END;
$$;

DROP FUNCTION IF EXISTS get_notifications;

CREATE FUNCTION get_notifications (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  include_read BOOLEAN
) RETURNS SETOF notifications LANGUAGE plpgsql AS $$
  BEGIN
    PERFORM validate_session(user_slug, given_session, session_lifetime);

    RETURN QUERY
      SELECT notifications.*
      FROM notifications LEFT JOIN users ON notifications."for" = users.id
      WHERE users.slug = user_slug AND (include_read OR read = FALSE);
  END;
$$;

DROP FUNCTION IF EXISTS login;

DROP FUNCTION IF EXISTS new_stake;

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
) RETURNS SETOF sessions LANGUAGE plpgsql AS $$
DECLARE
  new_user BOOLEAN;
  avatar_id avatars.id%TYPE;
  user_id users.id%TYPE;
  user_slug users.slug%TYPE;
  default_avatar avatars.default_index%TYPE;
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

  RETURN QUERY
    INSERT INTO sessions ("user", session, access_token, refresh_token, discord_expires)
      VALUES (
        user_id,
        given_session,
        given_access_token,
        given_refresh_token,
        (now() + discord_expires_in)
      ) RETURNING sessions.*;

  IF new_user THEN
    INSERT INTO jasb.audit_logs (event) VALUES (
      json_build_object(
        'event', 'NewUser',
        'user_slug', user_slug,
        'discord_id', given_discord_id,
        'balance', initial_balance
      )
    );
    INSERT INTO notifications ("for", notification) VALUES (
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

CREATE FUNCTION new_stake (
  min_stake stakes.amount%TYPE,
  notable_stake stakes.amount%TYPE,
  max_bet_while_in_debt stakes.amount%TYPE,
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE,
  option_slug options.slug%TYPE,
  staked stakes.amount%TYPE,
  given_message stakes.message%TYPE
) RETURNS INTEGER LANGUAGE plpgsql AS $$
  DECLARE
    bet_is_voting BOOLEAN;
    new_balance users.balance%TYPE;
  BEGIN
    PERFORM validate_session(user_slug, given_session, session_lifetime);

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
          SELECT options.id, users.id, staked, given_message
          FROM
            users INNER JOIN
              options ON users.slug = user_slug AND options.slug = option_slug INNER JOIN
              bets ON options.bet = bets.id AND bets.slug = bet_slug INNER JOIN
              games ON bets.game = games.id AND games.slug = game_slug
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

    INSERT INTO jasb.audit_logs (event) VALUES (
      json_build_object(
        'event', 'NewStake',
        'user_slug', user_slug,
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

DROP FUNCTION IF EXISTS revert_cancel_bet;

CREATE FUNCTION revert_cancel_bet (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  old_version bets.version%TYPE,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE
) RETURNS SETOF bets LANGUAGE plpgsql AS $$
  DECLARE
    bet_id bets.id%TYPE;
  BEGIN
    PERFORM validate_manage_bets(user_slug, given_session, session_lifetime, game_slug);

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

    INSERT INTO notifications ("for", notification) SELECT
      stakes.owner AS "for",
      json_build_object(
        'type', 'BetReverted',
        'game_slug', games.slug,
        'game_name', games.name,
        'bet_slug', bets.slug,
        'bet_name', bets.name,
        'option_slug', options.slug,
        'option_name', options.name,
        'reverted', bets.progress,
        'amount', coalesce(-stakes.amount, 0)
      ) AS notification
    FROM
      stakes LEFT JOIN
        options ON stakes.option = options.id INNER JOIN
        bets ON options.bet = bets.id AND bets.id = bet_id INNER JOIN
        games ON bets.game = games.id;

    RETURN QUERY UPDATE bets SET
      version = old_version + 1,
      resolved = NULL,
      cancelled_reason = NULL,
      progress = 'Locked'::BetProgress
    WHERE id = bet_id
    RETURNING bets.*;

    INSERT INTO jasb.audit_logs (event) VALUES (
      json_build_object(
        'event', 'RevertCancelBet',
        'user_slug', user_slug,
        'game_slug', game_slug,
        'bet_slug', bet_slug
      )
    );
  END;
$$;

DROP FUNCTION IF EXISTS revert_complete_bet;

CREATE FUNCTION revert_complete_bet (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  old_version bets.version%TYPE,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE
) RETURNS SETOF bets LANGUAGE plpgsql AS $$
  DECLARE
    bet_id bets.id%TYPE;
  BEGIN
    PERFORM validate_manage_bets(user_slug, given_session, session_lifetime, game_slug);

    SELECT bets.id
    INTO bet_id
    FROM bets INNER JOIN games ON bets.game = games.id
    WHERE games.slug = game_slug AND bets.slug = bet_slug AND bets.progress = 'Complete';
    IF NOT FOUND THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Bet must be complete to revert completion.';
    END IF;

    UPDATE users
    SET balance = users.balance - stakes.payout
    FROM stakes INNER JOIN options ON stakes.option = options.id AND options.bet = bet_id
    WHERE stakes.owner = users.id AND stakes.payout IS NOT NULL AND stakes.payout > 0;

    INSERT INTO notifications ("for", notification) SELECT
      stakes.owner AS "for",
      json_build_object(
        'type', 'BetReverted',
        'game_slug', games.slug,
        'game_name', games.name,
        'bet_slug', bets.slug,
        'bet_name', bets.name,
        'option_slug', options.slug,
        'option_name', options.name,
        'reverted', bets.progress,
        'amount', coalesce(-stakes.payout, 0)
      ) AS notification
    FROM
      stakes LEFT JOIN
        options ON stakes.option = options.id INNER JOIN
        bets ON options.bet = bets.id AND bets.id = bet_id INNER JOIN
        games ON bets.game = games.id;

    UPDATE stakes SET
      payout = NULL
    FROM
      options
    WHERE
      options.bet = bet_id AND
      stakes.option = options.id AND
      stakes.payout IS NOT NULL;

    UPDATE options SET
      version = version + 1,
      won = FALSE
    WHERE
      bet = bet_id AND
      won = TRUE;

    RETURN QUERY UPDATE bets SET
      version = old_version + 1,
      resolved = NULL,
      progress = 'Locked'::BetProgress
    WHERE id = bet_id
    RETURNING bets.*;

    INSERT INTO jasb.audit_logs (event) VALUES (
      json_build_object(
        'event', 'RevertCompleteBet',
        'user_slug', user_slug,
        'game_slug', game_slug,
        'bet_slug', bet_slug
      )
    );
  END;
$$;

DROP FUNCTION IF EXISTS set_bet_locked;

CREATE FUNCTION set_bet_locked (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  old_version bets.version%TYPE,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE,
  target_lock_state BOOLEAN
) RETURNS SETOF bets LANGUAGE plpgsql AS $$
  DECLARE
    target BetProgress;
    expected BetProgress;
  BEGIN
    PERFORM validate_manage_bets(user_slug, given_session, session_lifetime, game_slug);

    IF (target_lock_state) THEN
      target = 'Locked'::BetProgress;
      expected = 'Voting'::BetProgress;
    ELSE
      target = 'Voting'::BetProgress;
      expected = 'Locked'::BetProgress;
    END IF;

    RETURN QUERY UPDATE bets SET
      version = old_version + 1,
      progress = target
    FROM games
    WHERE
      bets.game = games.id AND
      games.slug = game_slug AND
      bets.slug = bet_slug AND
      bets.progress = expected
    RETURNING bets.*;

    INSERT INTO jasb.audit_logs (event) VALUES (
      json_build_object(
        'event', 'SetBetLocked',
        'user_slug', user_slug,
        'game_slug', game_slug,
        'bet_slug', bet_slug,
        'locked', target_lock_state
      )
    );
  END;
$$;

DROP FUNCTION IF EXISTS set_permissions;

CREATE FUNCTION set_permissions (
  editor_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  user_slug users.slug%TYPE,
  game_slug games.slug%TYPE,
  set_manage_games BOOLEAN,
  set_manage_permissions BOOLEAN,
  set_manage_bets BOOLEAN
) RETURNS SETOF users LANGUAGE plpgsql AS $$
  BEGIN
    PERFORM validate_manage_permissions(editor_slug, given_session, session_lifetime);

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
        manage_bets = coalesce(set_manage_bets, general_permissions.manage_bets)
      FROM users
      WHERE general_permissions.user = users.id AND users.slug = user_slug;
    END IF;

    RETURN QUERY SELECT users.* FROM users WHERE users.slug = user_slug;

    INSERT INTO jasb.audit_logs (event) VALUES (
      json_build_object(
        'event', 'SetPermission',
        'editor_slug', editor_slug,
        'user_slug', user_slug,
        'game_slug', game_slug,
        'manage_games', set_manage_games,
        'manage_permissions', set_manage_permissions,
        'manage_bets', set_manage_bets
      )
    );
  END;
$$;

DROP FUNCTION IF EXISTS set_read;

CREATE FUNCTION set_read (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  notification_id notifications.id%TYPE
) RETURNS BOOLEAN LANGUAGE plpgsql AS $$
  BEGIN
    PERFORM validate_session(user_slug, given_session, session_lifetime);

    UPDATE notifications
    SET read = TRUE
    FROM users
    WHERE notifications."for" = users.id AND users.slug = user_slug AND notifications.id = notification_id;

    IF FOUND THEN
      RETURN TRUE;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Notification not found.';
    END IF;
  END;
$$;

DROP FUNCTION IF EXISTS withdraw_stake;

CREATE FUNCTION withdraw_stake (
  user_slug users.slug%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  game_slug games.slug%TYPE,
  bet_slug bets.slug%TYPE,
  option_slug options.slug%TYPE
) RETURNS INTEGER LANGUAGE plpgsql AS $$
  DECLARE
    bet_is_voting BOOLEAN;
    new_balance users.balance%TYPE;
  BEGIN
    PERFORM validate_session(user_slug, given_session, session_lifetime);

    SELECT bets.progress = 'Voting'::BetProgress INTO bet_is_voting
    FROM bets INNER JOIN games ON bets.game = games.id
    WHERE games.slug = game_slug AND bets.slug = bet_slug;

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
        DELETE FROM stakes
          USING
            users INNER JOIN
              options ON options.slug = option_slug INNER JOIN
              bets ON bets.slug = bet_slug AND options.bet = bets.id INNER JOIN
              games ON games.slug = game_slug AND bets.game = games.id
          WHERE
            stakes.owner = users.id AND
            stakes.option = options.id AND
            stakes.message IS NULL
          RETURNING stakes.owner AS "user", stakes.amount
      )
    UPDATE users SET balance = balance + stake.amount FROM stake WHERE stake.user = users.id
    RETURNING balance INTO new_balance;

    IF FOUND THEN
      INSERT INTO jasb.audit_logs (event) VALUES (
        json_build_object(
          'event', 'WithdrawStake',
          'user_slug', user_slug,
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
