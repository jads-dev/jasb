/* Add payout column to stakes, filled when the bet is completed. */
ALTER TABLE jasb.stakes
  ADD COLUMN IF NOT EXISTS payout INT;

/* Add payouts for existing completed bets using old methodology. */
WITH
  stats AS (
    SELECT
      options.game,
      options.bet,
      COALESCE(SUM(stakes.amount)::INT, 0) AS total_staked,
      COALESCE(SUM(stakes.amount) FILTER (WHERE (options.won))::INT, 0) AS winning_staked
    FROM jasb.options INNER JOIN jasb.stakes ON
      options.game = stakes.game AND
        options.bet = stakes.bet AND
        options.id = stakes.option
    GROUP BY (options.game, options.bet)
  )
  UPDATE jasb.stakes SET
    payout = CASE options.won WHEN TRUE THEN
      CASE
        WHEN stats.winning_staked = 0 THEN 0
        ELSE ((stats.total_staked::float / stats.winning_staked::float) * stakes.amount)::int
      END
    ELSE
      0
    END
  FROM
    jasb.options INNER JOIN
    jasb.bets ON options.game = bets.game AND options.bet = bets.id INNER JOIN
    stats ON options.game = stats.game AND options.bet = stats.bet
  WHERE
    stakes.game = options.game AND
    stakes.bet = options.bet AND
    stakes.option = options.id AND
    bets.progress = 'Complete';

/* Create new payout method. */
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
              sum(total) FILTER (WHERE NOT is_winner) OVER () / (count(*) FILTER (WHERE is_winner) OVER ())
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

/* Drop old feed items to update. */
DROP VIEW IF EXISTS jasb.feed;
DROP VIEW IF EXISTS jasb.feed_bet_complete;
DROP VIEW IF EXISTS jasb.bet_stats;

/* Swap in payout rather than calculating here. */
CREATE OR REPLACE VIEW jasb.bet_stats AS
  WITH
    options AS (
      SELECT
        options.game,
        options.bet,
        COALESCE(
          ARRAY_AGG((options.*)::jasb.options ORDER BY options."order"),
          '{}'
        ) AS winners
      FROM jasb.options
      WHERE options.won
      GROUP BY (options.game, options.bet)
    ),
    stakes AS (
      SELECT
        options.game,
        options.bet,
        COALESCE(MAX(stakes.payout), 0) AS biggest_payout,
        COALESCE(SUM(stakes.amount)::INT, 0) AS total_staked,
        COUNT((stakes.option, stakes.owner)) FILTER (WHERE stakes.owner IS NOT NULL AND options.won)::INT AS winning_stakes,
        COUNT(stakes.owner) FILTER (WHERE (options.won))::INT AS winning_users
      FROM jasb.options INNER JOIN jasb.stakes ON
        options.game = stakes.game AND
        options.bet = stakes.bet AND
        options.id = stakes.option
      GROUP BY (options.game, options.bet)
    ),
    biggest_stakes_with_user AS (
      SELECT
        stakes.game,
        stakes.bet,
        stakes.owner,
        MIN(stakes.made_at) AS made_at
      FROM jasb.stakes
        INNER JOIN jasb.options ON
          options.game = stakes.game AND
          options.bet = stakes.bet AND
          options.id = stakes.option AND
          won = true
        INNER JOIN stakes AS stake_stats ON stakes.game = stake_stats.game AND stakes.bet = stake_stats.bet
      WHERE stakes.payout = stake_stats.biggest_payout
      GROUP BY (stakes.game, stakes.bet, stakes.owner)
    ),
    user_ids AS (
      SELECT
        stakes.game,
        stakes.bet,
        stakes.owner
      FROM
        biggest_stakes_with_user AS stakes INNER JOIN
        jasb.options ON stakes.game = options.game AND stakes.bet = options.bet
      WHERE options.won AND stakes.owner IS NOT NULL
      GROUP BY (stakes.game, stakes.bet, stakes.owner)
      ORDER BY MAX(stakes.made_at)
    ),
    users AS (
      SELECT
        user_ids.game,
        user_ids.bet,
        COALESCE(
          ARRAY_AGG(
            (users.*)::jasb.users
          ),
          '{}'
        ) AS top_winners
      FROM
        user_ids INNER JOIN jasb.users ON users.id = user_ids.owner
      GROUP BY (user_ids.game, user_ids.bet)
    )
    SELECT
      bets.game,
      bets.id,
      options.winners,
      users.top_winners,
      stakes.biggest_payout,
      stakes.total_staked,
      stakes.winning_stakes,
      stakes.winning_users
    FROM jasb.bets
      LEFT JOIN options ON options.game = bets.game AND options.bet = bets.id
      LEFT JOIN stakes ON stakes.game = bets.game AND stakes.bet = bets.id
      LEFT JOIN users ON users.game = bets.game AND users.bet = bets.id
    WHERE bets.progress = 'Complete'::BetProgress
    GROUP BY (
      bets.game,
      bets.id,
      options.winners,
      users.top_winners,
      stakes.biggest_payout,
      stakes.total_staked,
      stakes.winning_stakes,
      stakes.winning_users
     );

/* Use payout rather than calculating here. */
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
        'amount', bet_stats.biggest_payout
      ),
      'totalReturn', bet_stats.total_staked,
      'winningStakes', bet_stats.winning_stakes
    ) AS item
  FROM bets
    INNER JOIN games ON games.id = bets.game
    INNER JOIN bet_stats ON bet_stats.game = bets.game AND bet_stats.id = bets.id
  WHERE bets.progress = 'Complete';

/* Same thing, but using updated view. */
CREATE OR REPLACE VIEW jasb.feed AS
  SELECT * FROM feed_notable_stakes UNION ALL
  SELECT * FROM feed_bet_complete UNION ALL
  SELECT * FROM feed_new_bets;
