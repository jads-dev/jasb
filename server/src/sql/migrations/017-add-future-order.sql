/* Add order column to games, for the expected order. */
ALTER TABLE jasb.games
  ADD COLUMN IF NOT EXISTS "order" INT;

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
  clear_finished BOOLEAN DEFAULT FALSE,
  new_order games.order%TYPE DEFAULT NULL,
  clear_order BOOLEAN DEFAULT FALSE
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
      finished = CASE WHEN clear_finished THEN NULL ELSE COALESCE(new_finished, finished) END,
      "order" = CASE WHEN clear_order THEN NULL ELSE COALESCE(new_order, "order") END
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

CREATE OR REPLACE FUNCTION jasb.add_game(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  game_id games.id%TYPE,
  given_name games.name%TYPE,
  given_cover games.cover%TYPE,
  given_igdb_id games.igdb_id%TYPE,
  given_started games.started%TYPE,
  given_finished games.finished%TYPE,
  given_order games.order%TYPE
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
      given_finished,
      given_order
    ) RETURNING *;
  END;
$$;