ALTER TABLE games
  ADD COLUMN IF NOT EXISTS search TEXT GENERATED ALWAYS AS (
    lower(name) || ' ' || slug
  ) STORED;

CREATE INDEX games_search ON games USING GIN(search gin_trgm_ops);
