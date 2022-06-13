CREATE OR REPLACE FUNCTION jasb.add_game(
  user_id users.id % TYPE,
  given_session sessions.session % TYPE,
  session_lifetime INTERVAL,
  game_id games.id % TYPE,
  given_name games.name % TYPE,
  given_cover games.cover % TYPE,
  given_igdb_id games.igdb_id % TYPE,
  given_started games.started % TYPE,
  given_finished games.finished % TYPE,
  given_order games.order % TYPE
) 
  RETURNS SETOF jasb.games 
  LANGUAGE PLPGSQL 
AS $$
  BEGIN 
    PERFORM validate_admin(user_id, given_session, session_lifetime);

    RETURN QUERY INSERT INTO jasb.games 
      (id, name, cover, igdb_id, started, finished, "order")
    VALUES
      (
        game_id,
        given_name,
        given_cover,
        given_igdb_id,
        given_started,
        given_finished,
        given_order
      ) RETURNING *;
  END;
$$;
