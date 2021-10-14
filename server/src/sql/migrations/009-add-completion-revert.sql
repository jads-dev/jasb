CREATE OR REPLACE FUNCTION jasb.revert_complete_bet(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  old_version games.version%TYPE,
  game_id games.id%TYPE,
  bet_id bets.id%TYPE
)
  RETURNS SETOF jasb.bets
  LANGUAGE PLPGSQL
  VOLATILE
AS $$
  BEGIN
    PERFORM validate_manage_bets(user_id, given_session, session_lifetime, game_id);

    PERFORM
      TRUE
    FROM jasb.bets
    WHERE game = game_id AND id = bet_id AND progress = 'Complete';
    IF NOT FOUND THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Bet must be complete to revert completion.';
    END IF;

    UPDATE jasb.users SET
      balance = users.balance - stakes.payout
    FROM jasb.stakes
    WHERE
      stakes.game = game_id AND
      stakes.bet = bet_id AND
      stakes.owner = users.id AND
      stakes.payout IS NOT NULL AND
      stakes.payout > 0;

    UPDATE jasb.stakes SET
      payout = NULL
    WHERE
      stakes.game = game_id AND
      stakes.bet = bet_id AND
      stakes.payout IS NOT NULL;

    UPDATE jasb.options SET
      version = version + 1,
      won = FALSE
    WHERE
      game = game_id AND
      bet = bet_id AND
      won = TRUE;

    INSERT INTO jasb.notifications ("for", notification) SELECT
      stakes.owner AS "for",
      json_build_object(
        'type', 'BetReverted',
        'gameId', game_id,
        'gameName', games.name,
        'betId', bet_id,
        'betName', bets.name,
        'optionId', stakes.option,
        'optionName', options.name,
        'reverted', bets.progress,
        'amount', COALESCE(-stakes.payout, 0)
      ) AS notification
    FROM (
      jasb.stakes LEFT JOIN
      games ON stakes.game = games.id LEFT JOIN
      bets ON stakes.game = bets.game AND stakes.bet = bets.id LEFT JOIN
      options ON stakes.game = options.game AND stakes.bet = options.bet AND stakes.option = options.id
    ) WHERE stakes.game = game_id AND stakes.bet = bet_id;

    INSERT INTO jasb.audit_logs ("user", event) SELECT
      stakes.owner,
      json_build_object(
        'event', 'Revert',
        'game', game_id,
        'bet', bet_id,
        'option', stakes.option,
        'reverted', 'Complete',
        'amount', -stakes.payout
      )
    FROM jasb.stakes WHERE stakes.game = game_id AND stakes.bet = bet_id;

    RETURN QUERY UPDATE jasb.bets SET
      version = old_version + 1,
      resolved = NULL,
      progress = 'Locked'::BetProgress
    WHERE game = game_id AND id = bet_id
    RETURNING *;
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.revert_cancel_bet(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  old_version games.version%TYPE,
  game_id games.id%TYPE,
  bet_id bets.id%TYPE
)
  RETURNS SETOF jasb.bets
  LANGUAGE PLPGSQL
  VOLATILE
AS $$
  BEGIN
    PERFORM validate_manage_bets(user_id, given_session, session_lifetime, game_id);

    PERFORM
      TRUE
    FROM jasb.bets
    WHERE game = game_id AND id = bet_id AND progress = 'Cancelled';
    IF NOT FOUND THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Bet must be cancelled to revert cancellation.';
    END IF;

    UPDATE jasb.users SET
      balance = users.balance - stakes.amount
    FROM jasb.stakes
    WHERE
      stakes.game = game_id AND
      stakes.bet = bet_id AND
      stakes.owner = users.id;

    INSERT INTO jasb.notifications ("for", notification) SELECT
      stakes.owner AS "for",
      json_build_object(
        'type', 'BetReverted',
        'gameId', game_id,
        'gameName', games.name,
        'betId', bet_id,
        'betName', bets.name,
        'optionId', stakes.option,
        'optionName', options.name,
        'reverted', bets.progress,
        'amount', COALESCE(-stakes.payout, 0)
      ) AS notification
    FROM (
      jasb.stakes LEFT JOIN
      games ON stakes.game = games.id LEFT JOIN
      bets ON stakes.game = bets.game AND stakes.bet = bets.id LEFT JOIN
      options ON stakes.game = options.game AND stakes.bet = options.bet AND stakes.option = options.id
    ) WHERE stakes.game = game_id AND stakes.bet = bet_id;

    INSERT INTO jasb.audit_logs ("user", event) SELECT
      stakes.owner,
      json_build_object(
        'event', 'Revert',
        'game', game_id,
        'bet', bet_id,
        'option', stakes.option,
        'reverted', 'Cancelled',
        'amount', -stakes.payout
      )
    FROM jasb.stakes WHERE stakes.game = game_id AND stakes.bet = bet_id;

    RETURN QUERY UPDATE jasb.bets SET
      version = old_version + 1,
      resolved = NULL,
      cancelled_reason = NULL,
      progress = 'Locked'::BetProgress
    WHERE game = game_id AND id = bet_id
    RETURNING *;
  END;
$$;
