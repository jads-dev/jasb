CREATE OR REPLACE FUNCTION jasb.complete_bet(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  session_lifetime INTERVAL,
  old_version games.version%TYPE,
  game_id games.id%TYPE,
  bet_id bets.id%TYPE,
  winners TEXT[]
)
  RETURNS SETOF jasb.bets
  LANGUAGE PLPGSQL
AS $$
  BEGIN
    PERFORM validate_manage_bets(user_id, given_session, session_lifetime, game_id);

    RETURN QUERY WITH
      staked AS (
        SELECT
          option,
          sum(amount) as total,
          (option = ANY(winners)) AS is_winner
        FROM jasb.stakes
        WHERE game = game_id AND bet = bet_id
        GROUP BY (option)
      ),
      pot AS (
        SELECT
          option,
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
          stakes.owner AS "user",
          stakes.option,
          stakes.amount AS staked,
          CASE stakes.option = ANY(winners)
            WHEN TRUE THEN
              stakes.amount + (pot.amount / (sum(stakes.amount) OVER same_option) * stakes.amount)::INT
          END AS amount
        FROM jasb.stakes INNER JOIN pot ON stakes.option = pot.option
        WHERE stakes.game = game_id AND stakes.bet = bet_id
        WINDOW same_option AS (PARTITION BY stakes.option)
      ),
      updateWinners AS (
        UPDATE jasb.users SET
          balance = users.balance + payouts.amount
        FROM payouts WHERE payouts."user" = users.id AND payouts.amount IS NOT NULL
      ),
      updateStakes AS (
        UPDATE jasb.stakes SET
          payout = payouts.amount
        FROM payouts
        WHERE
          stakes.game = game_id AND
          stakes.bet = bet_id AND
          payouts.option = stakes.option AND
          payouts."user" = stakes.owner AND
          payouts.amount IS NOT NULL
      ),
      updateOptions AS (
        UPDATE jasb.options SET
          version = version + 1,
          won = TRUE
        WHERE
          game = game_id AND
          bet = bet_id AND
          id = ANY(winners)
      ),
      notifyUsers AS (
        INSERT INTO jasb.notifications ("for", notification) SELECT
          stakes.owner AS "for",
          json_build_object(
            'type', 'BetFinished',
            'gameId', game_id,
            'gameName', games.name,
            'betId', bet_id,
            'betName', bets.name,
            'optionId', stakes.option,
            'optionName', options.name,
            'result', CASE
              WHEN options.id = ANY(winners) THEN 'Win'
              ELSE 'Loss'
            END,
            'amount', COALESCE(payouts.amount, 0)
          ) AS notification
        FROM (
          jasb.stakes LEFT JOIN
          games ON stakes.game = games.id LEFT JOIN
          bets ON stakes.game = bets.game AND stakes.bet = bets.id LEFT JOIN
          options ON stakes.game = options.game AND stakes.bet = options.bet AND stakes.option = options.id LEFT JOIN
          payouts ON stakes.owner = payouts."user" AND stakes.option = payouts.option
        ) WHERE stakes.game = game_id AND stakes.bet = bet_id
      ),
      log AS (
        INSERT INTO jasb.audit_logs ("user", event) SELECT
          payouts."user",
          json_build_object(
            'event', 'Payout',
            'game', game_id,
            'bet', bet_id,
            'option', payouts.option,
            'stake', payouts.staked,
            'winnings', payouts.amount
          )
        FROM payouts WHERE payouts.amount IS NOT NULL
      )
      UPDATE jasb.bets SET
        version = old_version + 1,
        resolved = NOW(),
        progress = 'Complete'
      WHERE game = game_id AND id = bet_id AND progress IN ('Voting', 'Locked')
      RETURNING *;
  END;
$$;
