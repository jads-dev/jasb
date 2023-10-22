CREATE TYPE ObjectType AS ENUM ('avatar', 'cover', 'option', 'card', 'banner');

CREATE TABLE objects (
  id INT GENERATED ALWAYS AS IDENTITY,
  type ObjectType NOT NULL,
  name TEXT DEFAULT NULL,
  url TEXT NOT NULL,
  source_url TEXT NOT NULL,
  store_failures INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id, type)
) PARTITION BY LIST (type);
CREATE TABLE avatar_objects PARTITION OF objects (UNIQUE (id)) FOR VALUES IN ('avatar'::ObjectType);
CREATE TABLE cover_objects PARTITION OF objects (UNIQUE (id)) FOR VALUES IN ('cover'::ObjectType);
CREATE TABLE option_objects PARTITION OF objects (UNIQUE (id)) FOR VALUES IN ('option'::ObjectType);
CREATE TABLE card_objects PARTITION OF objects (UNIQUE (id)) FOR VALUES IN ('card'::ObjectType);
CREATE TABLE banner_objects PARTITION OF objects (UNIQUE (id)) FOR VALUES IN ('banner'::ObjectType);
CREATE INDEX ON objects (type);
CREATE INDEX ON objects (name);

ALTER TABLE users ADD COLUMN avatar_object INT REFERENCES avatar_objects(id);
WITH
  created AS (INSERT INTO objects (url, source_url, type) (SELECT url, url, 'avatar'::ObjectType FROM avatars) RETURNING id, url)
UPDATE users
SET avatar_object = created.id
FROM avatars INNER JOIN created ON avatars.url = created.url
WHERE users.avatar = avatars.id;
CREATE INDEX users_avatar_object ON users (avatar_object);

ALTER TABLE games ADD COLUMN cover_object INT REFERENCES cover_objects(id);
WITH
  created AS (INSERT INTO objects (url, source_url, type) (SELECT cover, cover, 'cover'::ObjectType FROM games) RETURNING id, url)
UPDATE games SET cover_object = created.id, version = version + 1 FROM created WHERE games.cover = created.url;
ALTER TABLE games ALTER COLUMN cover_object SET NOT NULL;
CREATE INDEX games_cover_object ON games (cover_object);

ALTER TABLE options ADD COLUMN image_object INT REFERENCES option_objects(id);
WITH
  created AS (INSERT INTO objects (url, source_url, type) (SELECT image, image, 'option'::ObjectType FROM options WHERE image IS NOT NULL) RETURNING id, url)
UPDATE options SET image_object = created.id, version = version + 1 FROM created WHERE options.image = created.url;
CREATE INDEX options_image_object ON options (image_object);

ALTER TABLE gacha_card_types ADD COLUMN image_object INT REFERENCES card_objects(id);
WITH
  created AS (INSERT INTO objects (url, source_url, type) (SELECT image, image, 'card'::ObjectType FROM gacha_card_types) RETURNING id, url)
UPDATE gacha_card_types SET image_object = created.id, version = version + 1 FROM created WHERE gacha_card_types.image = created.url;
ALTER TABLE gacha_card_types ALTER COLUMN image_object SET NOT NULL;
CREATE INDEX gacha_card_types_image_object ON gacha_card_types (image_object);

ALTER TABLE gacha_banners ADD COLUMN cover_object INT REFERENCES banner_objects(id);
WITH
  created AS (INSERT INTO objects (url, source_url, type) (SELECT cover, cover, 'banner'::ObjectType FROM gacha_banners) RETURNING id, url)
UPDATE gacha_banners SET cover_object = created.id, version = version + 1 FROM created WHERE gacha_banners.cover = created.url;
ALTER TABLE gacha_banners ALTER COLUMN cover_object SET NOT NULL;
CREATE INDEX gacha_banners_cover_object ON gacha_banners (cover_object);

ALTER TABLE users DROP COLUMN avatar CASCADE;
ALTER TABLE users RENAME avatar_object TO avatar;
DROP TABLE avatars;

ALTER TABLE games DROP COLUMN cover;
ALTER TABLE games RENAME cover_object TO cover;

ALTER TABLE options DROP COLUMN image;
ALTER TABLE options RENAME image_object TO image;

ALTER TABLE gacha_card_types DROP COLUMN image;
ALTER TABLE gacha_card_types RENAME image_object TO image;

ALTER TABLE gacha_banners DROP COLUMN cover;
ALTER TABLE gacha_banners RENAME cover_object TO cover;
