CREATE OR REPLACE FUNCTION jasb.new_stake(
  min_stake INT,
  notable_stake INT,
  max_stake_while_in_debt INT,
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

    IF staked < min_stake THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Staked amount must be at least the configured minimum stake.';
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

    IF new_balance < 0 AND staked > max_stake_while_in_debt THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Can’t place a bet of this size while in debt.';
    END IF;

    RETURN new_balance;
  END;
$$;

CREATE OR REPLACE FUNCTION jasb.change_stake(
  min_stake INT,
  notable_stake INT,
  max_stake_while_in_debt INT,
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
      min_stake,
      notable_stake,
      max_stake_while_in_debt,
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