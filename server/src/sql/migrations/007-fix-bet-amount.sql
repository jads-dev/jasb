CREATE OR REPLACE VIEW jasb.users_with_stakes AS
  SELECT
    users.*,
    COALESCE(SUM(stakes.amount)::INT, 0) AS staked
  FROM
    users LEFT JOIN
      (jasb.stakes INNER JOIN jasb.bets ON
        stakes.game = bets.game AND
        stakes.bet = bets.id AND
        is_active(bets.progress)
      ) ON users.id = stakes.owner
  GROUP BY users.id;
