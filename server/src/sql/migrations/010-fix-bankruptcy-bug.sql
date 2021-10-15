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
        'amount', initial_balance,
        'reason', 'Bankruptcy'
      )
    );
    RETURN result;
  END;
$$;
