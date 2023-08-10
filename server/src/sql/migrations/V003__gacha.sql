CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA pg_catalog;

CREATE DOMAIN probability AS NUMERIC(5, 5) CHECK (VALUE > 0);

CREATE DOMAIN color AS BYTEA CHECK (length(VALUE) = 4);

ALTER TABLE general_permissions 
  ADD COLUMN IF NOT EXISTS manage_gacha BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS search TEXT GENERATED ALWAYS AS (lower(
    CASE
      WHEN discriminator IS NULL THEN username
      ELSE username || '#' || discriminator
    END || ' ' || coalesce(display_name, '')
  )) STORED;

CREATE INDEX users_search ON users USING GIN(search gin_trgm_ops);

ALTER TABLE stakes
  ADD COLUMN IF NOT EXISTS gacha_payout_rolls INT,
  ADD COLUMN IF NOT EXISTS gacha_payout_scrap INT;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS rolls INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pity INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS guarantees INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS scrap INT NOT NULL DEFAULT 0,
  ADD CONSTRAINT gacha_rolls_not_negative CHECK (rolls >= 0),
  ADD CONSTRAINT gacha_pity_not_negative CHECK (pity >= 0),
  ADD CONSTRAINT gacha_guarantees_not_negative CHECK (guarantees >= 0),
  ADD CONSTRAINT gacha_scrap_not_negative CHECK (scrap >= 0);

CREATE TABLE
  gacha_banners (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slug TEXT NOT NULL CONSTRAINT unique_gacha_banner_slug UNIQUE,

    "name" TEXT NOT NULL,
    description TEXT NOT NULL,
    cover TEXT NOT NULL,
    foreground_color color NOT NULL,
    background_color color NOT NULL,
    "type" TEXT NOT NULL,
    active BOOLEAN NOT NULL,
    "order" INT NOT NULL CONSTRAINT unique_gacha_banner_order UNIQUE DEFERRABLE INITIALLY IMMEDIATE,

    creator INT NOT NULL REFERENCES users(id),
    created TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    "version" INT DEFAULT 0 NOT NULL,
    modified TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
  );

CREATE TRIGGER update_gacha_banner_version BEFORE UPDATE ON gacha_banners
  FOR EACH ROW EXECUTE PROCEDURE update_version();

INSERT INTO gacha_banners (
  slug,
  "name",
  description,
  cover,
  foreground_color,
  background_color,
  type,
  active,
  "order",
  creator
) VALUES
  ('jads', 'JADS', 'Your favourite JADS members.', '', '\xFFFFFFFF', '\x000000FF', 'Standard', FALSE, 0, 4),
  ('stream-memes', 'Stream Memes', 'Infinite references.', '', '\xFFFFFFFF', '\x000000FF', 'Standard', FALSE, 1, 4),
  ('joms', 'Joms', 'The very official mascot of JADS.', '', '\x000000FF', '\xFFFFFFFF', 'Standard', FALSE, 2, 4),
  ('chans', 'Chans', 'She may be an inanimate object, but she’s your waifu.', '', '\xFFFFFFFF', '\x000000FF', 'Standard', FALSE, 3, 4),
  ('emotes', 'Emotes', 'If you can’t get them as reactions, try getting them as cards.', '', '\xFFFFFFFF', '\x000000FF', 'Standard', FALSE, 4, 4);

CREATE TABLE
  gacha_rarities (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slug TEXT NOT NULL CONSTRAINT unique_gacha_rarity_slug UNIQUE,

    "name" TEXT NOT NULL,
    generation_weight INT NOT NULL
  );

CREATE INDEX gacha_rarity_generation_weight ON gacha_rarities(generation_weight);

INSERT INTO gacha_rarities (slug, "name", generation_weight)
VALUES
  ('m', 'Worth A Moon', 50),
  ('jb', 'Jam Bread', 33),
  ('pt', '+2', 10),
  ('crm', 'Cream', 5),
  ('mp', 'Masterpiece', 2);

CREATE TABLE
  gacha_card_types (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    "name" TEXT NOT NULL,
    description TEXT NOT NULL,
    image TEXT NOT NULL,
    rarity INT NOT NULL REFERENCES gacha_rarities(id),
    banner INT NOT NULL REFERENCES gacha_banners(id),
    retired BOOL DEFAULT FALSE,

    forged_by INT REFERENCES users(id),

    creator INT NOT NULL REFERENCES users(id),
    created TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    "version" INT DEFAULT 0 NOT NULL,
    modified TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,

    UNIQUE (id, rarity, retired)
  );

CREATE INDEX gacha_card_types_banner ON gacha_card_types(banner) WHERE NOT retired;
CREATE INDEX gacha_card_types_banner_and_rarity ON gacha_card_types(banner, rarity) WHERE NOT retired;
CREATE UNIQUE INDEX gacha_unique_active_forged_card_type_per_rarity_per_user ON
  gacha_card_types(forged_by, rarity) WHERE forged_by IS NOT NULL AND NOT retired;

CREATE TRIGGER update_gacha_card_type_version BEFORE UPDATE ON gacha_card_types
  FOR EACH ROW EXECUTE PROCEDURE update_version();

CREATE TABLE
  gacha_credits (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    card_type INT NOT NULL REFERENCES gacha_card_types(id),
    "user" INT REFERENCES users(id),
    name TEXT,
    reason TEXT NOT NULL,

    created TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    "version" INT DEFAULT 0 NOT NULL,
    modified TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,

    CONSTRAINT gacha_credits_user_or_name CHECK (
      (name IS NULL AND "user" IS NOT NULL) OR
      (name IS NOT NULL AND "user" IS NULL)
    )
  );

CREATE INDEX gacha_credits_card_type ON gacha_credits(card_type);

CREATE TRIGGER update_gacha_credits_version BEFORE UPDATE ON gacha_credits
  FOR EACH ROW EXECUTE PROCEDURE update_version();

CREATE TABLE
  gacha_qualities (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slug TEXT NOT NULL CONSTRAINT unique_gacha_quality_slug UNIQUE,

    "name" TEXT NOT NULL,
    description TEXT NOT NULL,
    random_chance probability
  );

INSERT INTO gacha_qualities (slug, "name", "description", random_chance)
VALUES
  ('self', 'Self-Made', 'I made this!', NULL),
  ('joms', 'Joms', 'This card seems... redder.', 0.01),
  ('weeb', 'Weeb', 'UwU what’s this Senpai?', 0.01),
  ('useless', 'Useless', 'A useless card. Wait... useless?!', 0.001),
  ('mistake', 'Mistaké', 'Mistakés were made.', 0.001),
  ('trans', 'Trans Rights', 'This card says trans rights.', 0.005);

CREATE TABLE
  gacha_cards (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    owner INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    "type" INT NOT NULL REFERENCES gacha_card_types(id),

    created TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,

    UNIQUE (id, owner)
  );

CREATE INDEX gacha_card_type ON gacha_cards("type");
CREATE INDEX gacha_card_owner ON gacha_cards(owner);
CREATE INDEX gacha_card_most_recent ON gacha_cards(created DESC);

CREATE TABLE
  gacha_card_highlights (
    card INT PRIMARY KEY REFERENCES gacha_cards(id) ON DELETE CASCADE,
    owner INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    "order" INT NOT NULL,
    message TEXT,

    FOREIGN KEY (card, owner) REFERENCES gacha_cards(id, owner),
    CONSTRAINT gacha_card_highlights_order_per_user UNIQUE (owner, "order") DEFERRABLE INITIALLY IMMEDIATE
  );

CREATE TABLE
  gacha_card_qualities (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    card INT NOT NULL REFERENCES gacha_cards(id) ON DELETE CASCADE,
    quality INT NOT NULL REFERENCES gacha_qualities(id),

    CONSTRAINT gacha_unique_quality_per_card UNIQUE (card, quality)
  );

-- Set up balances for existing users.
-- Award historic rewards.
-- Hardcoded here: scraps per roll = 5, scraps per lost bet reward = 2, rolls per won bet reward = 1

WITH
  updated_stakes AS (
    UPDATE stakes SET
      gacha_payout_rolls = CASE WHEN options.won THEN 1 ELSE 0 END,
      gacha_payout_scrap = CASE WHEN options.won THEN 0 ELSE 2 END
    FROM
      options INNER JOIN
      bets ON options.bet = bets.id INNER JOIN
      games ON bets.game = games.id
    WHERE
      stakes.option = options.id AND
      bets.progress = 'Complete'::BetProgress
    RETURNING stakes.*
  ),
  bet_stats AS MATERIALIZED (
    SELECT
      stakes.owner AS user_id,
      coalesce(sum(stakes.gacha_payout_rolls), 0) AS rolls,
      coalesce(sum(stakes.gacha_payout_scrap), 0) AS scrap
    FROM
      updated_stakes AS stakes
    GROUP BY
      stakes.owner
  ),
  balances AS (
    UPDATE users SET
      rolls = users.rolls + bet_stats.rolls + ((users.scrap + bet_stats.scrap) / 5),
      scrap = (users.scrap + bet_stats.scrap) % 5
    FROM bet_stats
    WHERE users.id = bet_stats.user_id
  )
  INSERT INTO notifications ("for", notification)
  SELECT
    bet_stats.user_id,
    jsonb_build_object(
     'type', 'GachaGifted',
     'amount', jsonb_build_object(
       'rolls', bet_stats.rolls,
       'scrap', bet_stats.scrap
     ),
     'reason', 'Historic'
     )
  FROM bet_stats
  WHERE bet_stats.rolls > 0 OR bet_stats.scrap > 0;