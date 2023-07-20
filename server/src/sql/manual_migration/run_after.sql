INSERT INTO jasb.avatars (hash, discord_user, default_index, cached, url)
SELECT DISTINCT
  old_users.avatar,
  CASE
    WHEN old_users.avatar IS NULL THEN
      NULL
    ELSE
      old_users.id
  END,
  CASE
    WHEN old_users.avatar IS NULL THEN
      default_avatar(old_users.id, old_users.discriminator)
    ELSE
      NULL
  END,
  old_users.avatar_cache IS NOT NULL,
  CASE
    WHEN old_users.avatar_cache IS NULL THEN
      discord_avatar_url(old_users.id, old_users.discriminator, old_users.avatar)
    ELSE
      old_users.avatar_cache
  END
FROM old_jasb.users AS old_users;

WITH
  users AS (
    INSERT INTO jasb.users (discord_id, username, discriminator, created, balance, avatar)
    SELECT
      old_users.id,
      old_users.name,
      old_users.discriminator,
      old_users.created,
      old_users.balance,
      avatars.id
    FROM
      old_jasb.users AS old_users INNER JOIN
      jasb.avatars ON (
        (old_users.avatar IS NOT NULL AND old_users.avatar = avatars.hash) OR
        (old_users.avatar IS NULL AND default_avatar(old_users.id, old_users.discriminator) = avatars.default_index)
      )
    RETURNING users.id, users.discord_id
  )
  INSERT INTO jasb.general_permissions ("user", manage_games, manage_permissions, manage_bets)
  SELECT
    users.id,
    TRUE,
    TRUE,
    TRUE
  FROM old_jasb.users AS old_users INNER JOIN users ON old_users.id = users.discord_id
  WHERE old_users.admin;

INSERT INTO jasb.games (slug, name, cover, started, finished, "order", version, created, modified)
SELECT
  old_games.id,
  old_games.name,
  old_games.cover,
  old_games.started,
  old_games.finished,
  old_games."order",
  old_games.version,
  old_games.added,
  old_games.modified
FROM old_jasb.games AS old_games;

INSERT INTO jasb.specific_permissions (game, "user", manage_bets)
SELECT
  games.id,
  users.id,
  old_perms.manage_bets
FROM
  old_jasb.per_game_permissions AS old_perms INNER JOIN
    jasb.games ON old_perms.game = games.slug INNER JOIN
    jasb.users ON old_perms."user" = users.discord_id;

WITH
  lock_moments AS (
    INSERT INTO jasb.lock_moments (slug, game, name, "order", created)
    SELECT
      (row_number() OVER (PARTITION BY games.id))::TEXT,
      games.id,
      old_bets.locks_when,
      row_number() OVER (PARTITION BY games.id),
      min(old_bets.created)
    FROM old_jasb.bets AS old_bets INNER JOIN games ON old_bets.game = games.slug
    GROUP BY (games.id, old_bets.locks_when)
    ORDER BY min(old_bets.created) DESC
    RETURNING lock_moments.id, lock_moments.game, lock_moments.name
  )
  INSERT INTO jasb.bets (game, slug, name, description, spoiler, author, lock_moment, progress, cancelled_reason, resolved, version, created, modified)
  SELECT
    games.id,
    old_bets.id,
    old_bets.name,
    old_bets.description,
    old_bets.spoiler,
    users.id,
    lock_moments.id,
    CASE old_bets.progress
      WHEN 'Voting'::old_jasb.BetProgress THEN 'Voting'::jasb.BetProgress
      WHEN 'Locked'::old_jasb.BetProgress THEN 'Locked'::jasb.BetProgress
      WHEN 'Complete'::old_jasb.BetProgress THEN 'Complete'::jasb.BetProgress
      WHEN 'Cancelled'::old_jasb.BetProgress THEN 'Cancelled'::jasb.BetProgress
    END,
    old_bets.cancelled_reason,
    old_bets.resolved,
    old_bets.version,
    old_bets.created,
    old_bets.modified
  FROM
    old_jasb.bets AS old_bets INNER JOIN
    jasb.users ON old_bets.by = users.discord_id INNER JOIN
    jasb.games ON old_bets.game = games.slug INNER JOIN
    lock_moments ON old_bets.locks_when = lock_moments.name AND games.id = lock_moments.game;

INSERT INTO jasb.options (slug, bet, name, image, won, "order", version, created, modified)
SELECT
  old_options.id,
  bets.id,
  old_options.name,
  old_options.image,
  old_options.won,
  old_options."order",
  old_options.version,
  old_options.created,
  old_options.modified
FROM
  old_jasb.options AS old_options INNER JOIN
  jasb.bets ON old_options.bet = bets.slug INNER JOIN
  jasb.games ON old_options.game = games.slug AND bets.game = games.id;

INSERT INTO jasb.stakes (option, owner, made_at, amount, message, payout)
SELECT
  options.id,
  users.id,
  old_stakes.made_at,
  old_stakes.amount,
  old_stakes.message,
  old_stakes.payout
FROM
  old_jasb.stakes AS old_stakes INNER JOIN
  jasb.users ON old_stakes.owner = users.discord_id INNER JOIN
  jasb.options AS options ON old_stakes.option = options.slug INNER JOIN
  jasb.bets ON old_stakes.bet = bets.slug AND options.bet = bets.id INNER JOIN
  jasb.games ON old_stakes.game = games.slug AND bets.game = games.id;