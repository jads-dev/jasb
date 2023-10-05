CREATE TYPE CardLayout AS ENUM('Normal', 'FullImage', 'LandscapeFullImage');

ALTER TABLE gacha_card_types
  ADD COLUMN IF NOT EXISTS layout CardLayout NOT NULL DEFAULT 'Normal'::CardLayout;
