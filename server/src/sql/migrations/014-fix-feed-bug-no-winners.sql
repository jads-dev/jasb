CREATE OR REPLACE VIEW jasb.feed_bet_complete AS
  SELECT
    games.id AS game,
    bets.id AS bet,
    bets.resolved AS time,
    JSONB_BUILD_OBJECT(
      'type', 'BetComplete',
      'game', JSONB_BUILD_OBJECT('id', games.id, 'name', games.name),
      'bet', JSONB_BUILD_OBJECT('id', bets.id, 'name', bets.name),
      'spoiler', bets.spoiler,
      'winners', (SELECT JSONB_AGG(JSONB_BUILD_OBJECT('id', id, 'name', name)) FROM UNNEST(bet_stats.winners)),
      'highlighted', JSONB_BUILD_OBJECT(
        'winners', TO_JSONB(COALESCE(bet_stats.top_winners, '{}')),
        'amount', COALESCE(bet_stats.biggest_payout, 0)
      ),
      'totalReturn', COALESCE(bet_stats.total_staked, 0),
      'winningStakes', COALESCE(bet_stats.winning_stakes, 0)
    ) AS item
  FROM bets
    INNER JOIN games ON games.id = bets.game
    INNER JOIN bet_stats ON bet_stats.game = bets.game AND bet_stats.id = bets.id
  WHERE bets.progress = 'Complete';