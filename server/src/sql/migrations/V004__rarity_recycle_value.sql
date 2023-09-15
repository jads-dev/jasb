ALTER TABLE gacha_rarities
  ADD COLUMN IF NOT EXISTS recycle_scrap_value INT NOT NULL DEFAULT 1;
