CREATE OR REPLACE FUNCTION jasb.set_permissions(
  editor_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  user_id users.id%TYPE,
  game_id games.id%TYPE,
  set_manage_bets per_game_permissions.manage_bets%TYPE
)
  RETURNS SETOF jasb.per_game_permissions
  LANGUAGE PLPGSQL
AS $$
  BEGIN
    PERFORM validate_admin(editor_id, given_session, session_lifetime);

    RETURN QUERY INSERT INTO
      jasb.per_game_permissions (game, "user", manage_bets)
    VALUES
      (game_id, user_id, set_manage_bets)
    ON CONFLICT ON CONSTRAINT per_game_permissions_pkey DO UPDATE SET
      manage_bets = COALESCE(set_manage_bets, per_game_permissions.manage_bets)
    RETURNING *;
  END;
$$;
