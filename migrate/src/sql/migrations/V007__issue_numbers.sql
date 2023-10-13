CREATE TABLE gacha_card_types_meta (
  type INT NOT NULL PRIMARY KEY REFERENCES gacha_card_types(id) ON DELETE CASCADE,
  next_issue_number INT NOT NULL DEFAULT 0
);

ALTER TABLE gacha_cards
  ADD COLUMN IF NOT EXISTS issue_number INT NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION update_next_issue_number()
RETURNS TRIGGER AS $$
  BEGIN
    SELECT next_issue_number INTO NEW.issue_number FROM jasb.gacha_card_types_meta WHERE type = NEW.type;
    INSERT INTO jasb.gacha_card_types_meta AS card_types_meta (type, next_issue_number) VALUES (NEW.type, 0)
    ON CONFLICT ON CONSTRAINT gacha_card_types_meta_pkey DO
      UPDATE SET next_issue_number = card_types_meta.next_issue_number + 1;
    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_next_issue_number_trigger BEFORE INSERT ON jasb.gacha_cards
  FOR EACH ROW EXECUTE FUNCTION update_next_issue_number();

WITH
  issue_numbers AS (
    SELECT
      cards.id,
      row_number() OVER (PARTITION BY card_types.id ORDER BY cards.id) - 1 AS issue_number
    FROM
      jasb.gacha_cards AS cards INNER JOIN jasb.gacha_card_types AS card_types ON cards.type = card_types.id
  )
  UPDATE jasb.gacha_cards AS cards
  SET issue_number = issue_numbers.issue_number
  FROM issue_numbers
  WHERE cards.id = issue_numbers.id;

CREATE UNIQUE INDEX unique_issue_number ON gacha_cards(type, issue_number);

INSERT INTO jasb.gacha_card_types_meta(type, next_issue_number)
SELECT
  card_types.id,
  coalesce(
    (SELECT max(cards.issue_number) + 1 FROM jasb.gacha_cards AS cards WHERE cards.type = card_types.id),
    0
  )
FROM gacha_card_types AS card_types;

INSERT INTO jasb.gacha_qualities (slug, name, description, random_chance)
  VALUES ('censored', 'Censored', 'At least it isn’t black bars.', 0.0025);
