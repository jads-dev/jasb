CREATE OR REPLACE VIEW jasb.game_bet_stats AS
  SELECT
    games.id AS game,
    COUNT(bets.id)::INT AS bets
  FROM games LEFT JOIN bets ON games.id = bets.game
  GROUP BY games.id;
