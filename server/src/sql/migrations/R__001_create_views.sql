DROP FUNCTION IF EXISTS is_active CASCADE;

CREATE FUNCTION is_active (progress BetProgress) RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE PARALLEL SAFE AS $$
  SELECT progress IN ('Voting'::BetProgress, 'Locked'::BetProgress)
$$;

DROP FUNCTION IF EXISTS is_hidden CASCADE;

CREATE FUNCTION is_hidden (progress BetProgress) RETURNS BOOLEAN LANGUAGE SQL IMMUTABLE PARALLEL SAFE AS $$
  SELECT progress = 'Cancelled'::BetProgress
$$;

DROP VIEW IF EXISTS bet_stats CASCADE;

CREATE VIEW
  bet_stats (
    game_id,
    bet_id,
    winning_options,
    top_winning_users,
    top_winning_discord_ids,
    biggest_payout_amount,
    total_staked_amount,
    winning_stakes_count,
    winning_users_count
  ) AS
WITH
  winning_options_by_bet AS (
    SELECT
      bets.id AS bet_id,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'slug', "options".slug,
            'name', "options".name
          )
          ORDER BY "options"."order"
        ) FILTER ( WHERE "options".id IS NOT NULL ),
        '[]'::jsonb
      ) AS winning_options
    FROM
      bets LEFT JOIN options ON bets.id = options.bet AND "options".won
    GROUP BY
      bets.id
  ),
  stake_stats_by_bet AS (
    SELECT
      bets.id AS bet_id,
      coalesce(max(stakes.payout), 0) AS biggest_payout_amount,
      coalesce(sum(stakes.amount)::INT, 0) AS total_staked_amount,
      count(ROW (stakes.option, stakes.owner)) FILTER (
        WHERE
          stakes.owner IS NOT NULL
          AND "options".won
      )::INT AS winning_stake_count,
      -- Different if a user won on >1 stakes on different winning options.
      count(stakes.owner) FILTER (
        WHERE
          "options".won
      )::INT AS winning_user_count
    FROM
      bets LEFT JOIN (options INNER JOIN stakes ON "options".id = stakes.option) ON bets.id = options.bet
    GROUP BY
      bets.id
  ),
  top_winning_users_by_bet AS (
    SELECT
      bets.id AS bet_id,
      coalesce(jsonb_agg(
        DISTINCT jsonb_build_object(
          'slug', users.slug,
          'name', users.name,
          'discriminator', users.discriminator,
          'avatar_url', avatars.url
        )
      ) FILTER ( WHERE users.id IS NOT NULL ), '[]'::jsonb) AS top_winners,
      coalesce(jsonb_agg(
        DISTINCT users.discord_id
      ) FILTER ( WHERE users.discord_id IS NOT NULL ), '[]'::jsonb) AS top_winners_discord_ids
    FROM
      bets INNER JOIN
      stake_stats_by_bet ON bets.id = stake_stats_by_bet.bet_id LEFT JOIN (
        stakes INNER JOIN
        "options" ON stakes.option = "options".id INNER JOIN
        users ON users.id = stakes.owner INNER JOIN
        avatars ON users.avatar = avatars.id
      ) ON bets.id = options.bet AND stakes.payout = stake_stats_by_bet.biggest_payout_amount
    GROUP BY
      bets.id
  )
SELECT
  bets.game AS game_id,
  bets.id AS bet_id,
  winning_options_by_bet.winning_options,
  top_winning_users_by_bet.top_winners,
  top_winning_users_by_bet.top_winners_discord_ids,
  stake_stats_by_bet.biggest_payout_amount,
  stake_stats_by_bet.total_staked_amount,
  stake_stats_by_bet.winning_stake_count,
  stake_stats_by_bet.winning_user_count
FROM
  bets INNER JOIN
    winning_options_by_bet ON bets.id = winning_options_by_bet.bet_id INNER JOIN
    stake_stats_by_bet ON bets.id = stake_stats_by_bet.bet_id INNER JOIN
    top_winning_users_by_bet ON bets.id = top_winning_users_by_bet.bet_id
WHERE
  bets.progress = 'Complete'::BetProgress;

DROP VIEW IF EXISTS feed_bet_complete CASCADE;

CREATE VIEW
  feed_bet_complete (game_slug, bet_slug, "time", item) AS
SELECT
  games.slug AS game_slug,
  bets.slug AS bet_slug,
  bets.resolved AS "time",
  jsonb_build_object(
    'type', 'BetComplete',
    'game', jsonb_build_object('slug', games.slug, 'name', games."name"),
    'bet', jsonb_build_object('slug', bets.slug, 'name', bets."name"),
    'spoiler', bets.spoiler,
    'winners', bet_stats.winning_options,
    'highlighted',
    jsonb_build_object(
      'winners', coalesce(bet_stats.top_winning_users, '[]'::jsonb),
      'amount', coalesce(bet_stats.biggest_payout_amount, 0)
    ),
    'totalReturn', coalesce(bet_stats.total_staked_amount, 0),
    'winningStakes', coalesce(bet_stats.winning_stakes_count, 0)
  ) AS item
FROM
  bets INNER JOIN
    games ON bets.game = games.id INNER JOIN
    bet_stats ON bets.id = bet_stats.bet_id
WHERE
  bets.progress = 'Complete'::BetProgress;

DROP VIEW IF EXISTS feed_new_bets CASCADE;

CREATE VIEW
  feed_new_bets (game_slug, bet_slug, "time", item) AS
SELECT
  games.slug AS game_slug,
  bets.slug AS bet_slug,
  bets.created AS "time",
  jsonb_build_object(
    'type', 'NewBet',
    'game', jsonb_build_object('slug', games.slug, 'name', games.name),
    'bet', jsonb_build_object('slug', bets.slug, 'name', bets.name),
    'spoiler', bets.spoiler
  ) AS item
FROM
  bets INNER JOIN games ON games.id = bets.game
WHERE
  bets.progress <> 'Cancelled'::BetProgress;

DROP VIEW IF EXISTS feed_notable_stakes CASCADE;

CREATE VIEW
  feed_notable_stakes (game_slug, bet_slug, "time", item) AS
SELECT
  games.slug AS game_slug,
  bets.slug AS bet_slug,
  stakes.made_at AS "time",
  jsonb_build_object(
    'type', 'NotableStake',
    'game', jsonb_build_object('slug', games.slug, 'name', games.name),
    'bet', jsonb_build_object('slug', bets.slug, 'name', bets.name),
    'spoiler', bets.spoiler,
    'option', jsonb_build_object('slug', "options".slug, 'name', "options".name),
    'user', jsonb_build_object(
      'slug', users.slug,
      'name', users.name,
      'discriminator', users.discriminator,
      'avatar_url', avatars.url
    ),
    'message', stakes.message,
    'stake', stakes.amount
  ) AS item
FROM
  stakes
    INNER JOIN users ON stakes.owner = users.id
    INNER JOIN avatars ON users.avatar = avatars.id
    INNER JOIN options ON stakes.option = "options".id
    INNER JOIN bets ON "options".bet = bets.id
    INNER JOIN games ON bets.game = games.id
WHERE
  stakes.message IS NOT NULL;

DROP VIEW IF EXISTS feed CASCADE;

CREATE VIEW
  feed (game_slug, bet_slug, "time", item) AS
SELECT * FROM feed_notable_stakes
  UNION ALL
SELECT * FROM feed_bet_complete
  UNION ALL
SELECT * FROM feed_new_bets;

DROP VIEW IF EXISTS game_bet_stats CASCADE;

CREATE VIEW
  game_bet_stats (game_id, bet_count) AS
SELECT
  games.id AS game_id,
  count(bets.id)::INT AS bet_count
FROM
  games LEFT JOIN bets ON games.id = bets.game
GROUP BY
  games.id;

DROP VIEW IF EXISTS bet_managers CASCADE;

CREATE VIEW
  bet_managers (game_id, users) AS
SELECT
  games.id AS game_id,
  jsonb_agg(jsonb_build_object(
    'slug', users.slug,
    'name', users.name,
    'discriminator', users.discriminator,
    'avatar_url', avatars.url
  )) FILTER (
    WHERE users.id IS NOT NULL
  ) AS users
FROM
  games LEFT JOIN
    specific_permissions ON
      games.id = specific_permissions.game AND
      specific_permissions.manage_bets LEFT JOIN
    (
      users INNER JOIN avatars ON users.avatar = avatars.id
    ) ON specific_permissions."user" = users.id
GROUP BY
  games.id;

DROP VIEW IF EXISTS game_stake_stats CASCADE;

CREATE VIEW
  game_stake_stats (game_id, total_staked_amount) AS
SELECT
  games.id AS game_id,
  sum(stakes.amount)::INT AS total_staked_amount
FROM
  games
  JOIN bets ON games.id = bets.game
  JOIN options ON bets.id = "options".bet
  JOIN stakes ON "options".id = stakes.option
GROUP BY
  games.id;

DROP VIEW IF EXISTS user_stakes CASCADE;

CREATE VIEW
  user_stakes (
    user_id,
    staked
  ) AS
SELECT
  users.id AS user_id,
  coalesce(sum(stakes.amount)::INT, 0) AS staked
FROM
  users
  LEFT JOIN (
    stakes INNER JOIN
    options ON stakes.option = "options".id INNER JOIN
    bets ON "options".bet = bets.id AND is_active(bets.progress)
  ) ON users.id = stakes.owner
GROUP BY users.id;

DROP VIEW IF EXISTS leaderboard CASCADE;

CREATE VIEW
  leaderboard (
    id,
    "slug",
    "name",
    discriminator,
    avatar_url,
    created,
    balance,
    staked,
    net_worth,
    "rank"
  ) AS
SELECT
  users.id,
  users.slug,
  users."name",
  users.discriminator,
  avatars.url AS avatar_url,
  users.created,
  users.balance,
  user_stakes.staked,
  user_stakes.staked + users.balance AS net_worth,
  (rank() OVER (
    ORDER BY
      (user_stakes.staked + users.balance) DESC
  ))::INT AS "rank"
FROM
  users INNER JOIN
  user_stakes ON users.id = user_stakes.user_id INNER JOIN
  avatars ON users.avatar = avatars.id;

DROP VIEW IF EXISTS debt_leaderboard CASCADE;

CREATE VIEW
  debt_leaderboard (
    id,
    "slug",
    "name",
    discriminator,
    avatar_url,
    created,
    balance,
    staked,
    net_worth,
    "rank"
  ) AS
SELECT
  users.id,
  users.slug,
  users."name",
  users.discriminator,
  avatars.url AS avatar_url,
  users.created,
  users.balance,
  user_stakes.staked,
  user_stakes.staked + users.balance AS net_worth,
  (rank() OVER (ORDER BY users.balance ASC))::INT AS "rank"
FROM
  users INNER JOIN
  user_stakes ON users.id = user_stakes.user_id INNER JOIN
  avatars ON users.avatar = avatars.id
WHERE
  balance < 0;

DROP VIEW IF EXISTS stakes_by_option CASCADE;

CREATE VIEW
  stakes_by_option ("option", stakes) AS
SELECT
  stakes.option,
  coalesce(jsonb_agg(
    jsonb_build_object(
      'user', jsonb_build_object(
        'slug', users.slug,
        'name', users.name,
        'discriminator', users.discriminator,
        'avatar_url', avatars.url
      ),
      'made_at', stakes.made_at,
      'amount', stakes.amount,
      'message', stakes.message
    )
    ORDER BY stakes.made_at
  ), '[]'::jsonb) AS stakes
FROM
  stakes INNER JOIN
    users ON stakes.owner = users.id INNER JOIN
    avatars ON users.avatar = avatars.id
GROUP BY
  stakes.option;

DROP VIEW IF EXISTS options_by_bet CASCADE;

CREATE VIEW
  options_by_bet (bet, "options") AS
SELECT
  "options".bet,
  coalesce(jsonb_agg(
    jsonb_build_object(
      'slug', options.slug,
      'name', options.name,
      'image', options.image,
      'stakes', coalesce(stakes.stakes, '[]'::jsonb),
      'won', options.won
    )
    ORDER BY "options"."order"
  ), '[]'::jsonb) AS options
FROM
  "options" LEFT JOIN stakes_by_option AS stakes ON "options".id = stakes.option
GROUP BY
  "options".bet;

CREATE VIEW
  editable_options_by_bet (bet, "options") AS
SELECT
  "options".bet,
  coalesce(jsonb_agg(
    jsonb_build_object(
      'slug', options.slug,
      'name', options.name,
      'image', options.image,
      'stakes', coalesce(stakes.stakes, '[]'::jsonb),
      'won', options.won,
      'order', options.order,
      'version', options.version,
      'created', options.created,
      'modified', options.modified
    )
    ORDER BY "options"."order"
  ), '[]'::jsonb) AS options
FROM
  "options" LEFT JOIN stakes_by_option AS stakes ON "options".id = stakes.option
GROUP BY
  "options".bet;

DROP VIEW IF EXISTS per_game_permissions CASCADE;

CREATE VIEW
  per_game_permissions (game, "user", manage_bets) AS
(
  SELECT
    games.id AS game,
    general_permissions."user",
    general_permissions.manage_bets
  FROM
    games CROSS JOIN general_permissions
  WHERE 
    general_permissions.manage_bets
) UNION (
  SELECT
    specific_permissions.game,
    specific_permissions."user",
    specific_permissions.manage_bets
  FROM
    specific_permissions 
  WHERE 
    specific_permissions.manage_bets
);