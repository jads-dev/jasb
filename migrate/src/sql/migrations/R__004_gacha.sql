DROP TYPE IF EXISTS OrderedBanner CASCADE;
CREATE TYPE OrderedBanner AS (
  slug TEXT,
  "version" INT
);

DROP TYPE IF EXISTS AddCredit CASCADE;
CREATE TYPE AddCredit AS (
  reason TEXT,
  "name" TEXT,
  "user" TEXT
);

DROP TYPE IF EXISTS EditCredit CASCADE;
CREATE TYPE EditCredit AS (
  id INT,
  reason TEXT,
  "name" TEXT,
  "user" TEXT,
  version INT
);

DROP TYPE IF EXISTS RemoveCredit CASCADE;
CREATE TYPE RemoveCredit AS (
  id INT,
  version INT
);

DROP FUNCTION IF EXISTS validate_manage_gacha CASCADE;
CREATE FUNCTION validate_manage_gacha (
  credential JSONB,
  session_lifetime INTERVAL
) RETURNS users.id%TYPE LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    can_manage_gacha BOOLEAN;
  BEGIN
    user_id = validate_credentials(credential, session_lifetime);
    SELECT INTO can_manage_gacha
      general_permissions.manage_gacha
    FROM general_permissions
    WHERE general_permissions."user" = user_id;
    IF can_manage_gacha THEN
      RETURN user_id;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'FRBDN',
        MESSAGE = 'Missing permission: manage gacha.';
    END IF;
  END;
$$;

DROP MATERIALIZED VIEW IF EXISTS gacha_rarity_cumulative_chance CASCADE;
CREATE MATERIALIZED VIEW
  gacha_rarity_cumulative_chance (rarity, cumulative_chance, is_max_rarity) AS
SELECT
  rarities.id,
  (
    sum(generation_weight) OVER (ORDER BY generation_weight) /
      (sum(generation_weight) OVER ())::DOUBLE PRECISION
  ) AS cumulative_chance,
  rarities.generation_weight = (min(rarities.generation_weight) OVER ())
FROM gacha_rarities AS rarities
ORDER BY cumulative_chance;

DROP FUNCTION IF EXISTS refresh_gacha_rarity_cumulative_chance CASCADE;
CREATE OR REPLACE FUNCTION refresh_gacha_rarity_cumulative_chance() RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
  BEGIN
    REFRESH MATERIALIZED VIEW gacha_rarity_cumulative_chance;
    RETURN NULL;
  END
$$;

DROP TRIGGER IF EXISTS refresh_gacha_rarity_cumulative_chance ON gacha_rarities;
CREATE TRIGGER refresh_gacha_rarity_cumulative_chance AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE
  ON gacha_rarities
  FOR EACH STATEMENT EXECUTE PROCEDURE refresh_gacha_rarity_cumulative_chance();

DROP FUNCTION IF EXISTS gacha_roll_internal CASCADE;
CREATE FUNCTION gacha_roll_internal (
  user_id users.id%TYPE,
  max_pity users.pity%TYPE,
  banner_id gacha_banners.id%TYPE,
  use_guarantees BOOL
) RETURNS gacha_cards LANGUAGE plpgsql AS $$
  DECLARE
    rarity_id gacha_rarities.id%TYPE;
    pity_reset BOOLEAN;
    card_type_id gacha_card_types.id%TYPE;
    card gacha_cards%ROWTYPE;
  BEGIN
    IF use_guarantees THEN
      SELECT id, FALSE
      INTO rarity_id, pity_reset
      FROM gacha_rarities
      ORDER BY generation_weight
      LIMIT 1;
    ELSE
      SELECT
        rarities.rarity,
        rarities.is_max_rarity
      INTO rarity_id, pity_reset
      FROM gacha_rarity_cumulative_chance as rarities
      WHERE (SELECT random()) <= rarities.cumulative_chance
      ORDER BY rarities.cumulative_chance
      LIMIT 1;
    END IF;

    SELECT card_types.id
    INTO card_type_id
    FROM gacha_card_types AS card_types
    WHERE
      card_types.rarity = rarity_id AND
      card_types.banner = banner_id AND
      NOT card_types.retired
    ORDER BY random()
    LIMIT 1;

    INSERT INTO gacha_cards (owner, "type")
    VALUES (user_id, card_type_id)
    RETURNING * INTO card;

    INSERT INTO gacha_card_qualities (card, quality)
    SELECT
      card.id AS card,
      qualities.id AS quality
    FROM gacha_qualities AS qualities
    WHERE qualities.random_chance IS NOT NULL AND random() <= qualities.random_chance;

    DECLARE
      violation TEXT;
    BEGIN
      UPDATE jasb.users SET
        rolls = rolls - 1,
        pity = CASE
          WHEN use_guarantees THEN pity
          WHEN pity_reset OR (pity + 1 > max_pity) THEN 0
          ELSE pity + 1
        END,
        guarantees = CASE
          WHEN use_guarantees THEN guarantees - 1
          ELSE CASE
            WHEN (NOT pity_reset) AND (pity + 1 > max_pity) THEN guarantees + 1
            ELSE guarantees
          END
        END
      WHERE id = user_id;
    EXCEPTION
      WHEN UNIQUE_VIOLATION THEN
        GET STACKED DIAGNOSTICS violation := CONSTRAINT_NAME;
        IF violation = 'gacha_balance_not_negative' THEN
          RAISE EXCEPTION USING
            ERRCODE = 'BDREQ',
            MESSAGE = 'Can‘t afford roll.';
        ELSEIF violation = 'gacha_guarantees_not_negative' THEN
          RAISE EXCEPTION USING
            ERRCODE = 'BDREQ',
            MESSAGE = 'Can‘t afford guaranteed roll.';
        ELSE
          RAISE;
        END IF;
    END;

    RETURN card;
  END;
$$;

DROP FUNCTION IF EXISTS gacha_roll CASCADE;
CREATE FUNCTION gacha_roll (
  credential JSONB,
  session_lifetime INTERVAL,
  max_pity users.pity%TYPE,
  banner_slug gacha_banners.slug%TYPE,
  roll_count INT,
  use_guarantees BOOL
) RETURNS SETOF gacha_cards LANGUAGE plpgsql ROWS 10 AS $$
  DECLARE
    user_id users.id%TYPE;
    banner_id gacha_banners.id%TYPE;
    banner_active gacha_banners.active%TYPE;
  BEGIN
    SELECT validate_credentials(credential, session_lifetime) INTO user_id;

    SELECT id, active INTO banner_id, banner_active FROM gacha_banners WHERE slug = banner_slug;
    IF banner_id IS NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Banner not found.';
    END IF;
    IF NOT banner_active THEN
      RAISE EXCEPTION USING
        ERRCODE = 'BDREQ',
        MESSAGE = 'Banner not active.';
    END IF;

    FOR _ IN 1..roll_count LOOP
      RETURN NEXT gacha_roll_internal(
        user_id,
        max_pity,
        banner_id,
        use_guarantees
      );
    END LOOP;

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'GachaRoll',
        'user_id', user_id,
        'banner_slug', banner_slug,
        'roll_count', roll_count
      )
    );
  END;
$$;

DROP FUNCTION IF EXISTS gacha_add_banner CASCADE;
CREATE FUNCTION gacha_add_banner (
  credential JSONB,
  session_lifetime INTERVAL,
  given_slug gacha_banners.slug%TYPE,
  given_name gacha_banners."name"%TYPE,
  given_description gacha_banners.description%TYPE,
  given_cover objects.url%TYPE,
  given_active gacha_banners.active%TYPE,
  given_type gacha_banners.type%TYPE,
  given_background_color gacha_banners.background_color%TYPE,
  given_foreground_color gacha_banners.foreground_color%TYPE
) RETURNS gacha_banners LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    banner gacha_banners%ROWTYPE;
  BEGIN
    SELECT validate_manage_gacha(credential, session_lifetime)
    INTO user_id;

    INSERT INTO gacha_banners
      (slug, name, description, cover, active, type, background_color, foreground_color, "order", creator)
    SELECT
      given_slug,
      given_name,
      given_description,
      add_object('banner'::ObjectType, given_cover),
      given_active,
      given_type,
      given_background_color,
      given_foreground_color,
      coalesce(max(existing."order"), 0) + 1,
      user_id
    FROM
      gacha_banners AS existing
    GROUP BY ()
    RETURNING gacha_banners.* INTO banner;

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'GachaAddBanner',
        'user_id', user_id,
        'banner_slug', given_slug
      )
    );

    RETURN banner;
  END;
$$;

DROP FUNCTION IF EXISTS gacha_edit_banner CASCADE;
CREATE FUNCTION gacha_edit_banner (
  credential JSONB,
  session_lifetime INTERVAL,
  banner_slug gacha_banners.slug%TYPE,
  old_version gacha_banners.version%TYPE,
  given_name gacha_banners."name"%TYPE,
  given_description gacha_banners.description%TYPE,
  given_cover objects.url%TYPE,
  given_active gacha_banners.active%TYPE,
  given_type gacha_banners.type%TYPE,
  given_background_color gacha_banners.background_color%TYPE,
  given_foreground_color gacha_banners.foreground_color%TYPE
) RETURNS gacha_banners LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    result gacha_banners%ROWTYPE;
  BEGIN
    SELECT validate_manage_gacha(credential, session_lifetime) INTO user_id;
    UPDATE gacha_banners SET
      version = old_version + 1,
      name = coalesce(given_name, name),
      description = coalesce(given_description, description),
      cover = update_object('banner'::ObjectType, cover, given_cover),
      active = coalesce(given_active, active),
      type = coalesce(given_type, type),
      background_color = coalesce(given_background_color, background_color),
      foreground_color = coalesce(given_foreground_color, foreground_color)
    WHERE gacha_banners.slug = banner_slug
    RETURNING gacha_banners.* INTO result;
    IF FOUND THEN
      INSERT INTO audit_logs (event) VALUES (
        jsonb_build_object(
          'event', 'GachaEditBanner',
          'user_id', user_id,
          'banner_slug', banner_slug,
          'from_version', old_version
        )
      );
      RETURN result;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Banner not found.';
    END IF;
  END;
$$;


DROP FUNCTION IF EXISTS gacha_reorder_banners CASCADE;
CREATE FUNCTION gacha_reorder_banners (
  credential JSONB,
  session_lifetime INTERVAL,
  new_order OrderedBanner[]
) RETURNS SETOF gacha_banners LANGUAGE plpgsql AS $$
  BEGIN
    PERFORM validate_manage_gacha(credential, session_lifetime);

    SET CONSTRAINTS unique_gacha_banner_order DEFERRED;

    RETURN QUERY
      UPDATE gacha_banners AS banners SET
        version = new_order.version + 1,
        "order" = new_order."order"
      FROM (
        SELECT
          slug,
          version,
          row_number() OVER () AS "order"
        FROM unnest(new_order) AS given(slug, version)
      ) AS new_order
      WHERE banners.slug = new_order.slug
      RETURNING banners.*;

    SET CONSTRAINTS unique_gacha_banner_order IMMEDIATE;
  END;
$$;

DROP FUNCTION IF EXISTS gacha_add_card_type CASCADE;
CREATE FUNCTION gacha_add_card_type (
  credential JSONB,
  session_lifetime INTERVAL,
  given_banner_slug gacha_banners.slug%TYPE,
  given_name gacha_card_types."name"%TYPE,
  given_description gacha_card_types.description%TYPE,
  given_image objects.url%TYPE,
  given_rarity_slug gacha_rarities.slug%TYPE,
  given_layout gacha_card_types.layout%TYPE,
  credits AddCredit[]
) RETURNS gacha_card_types LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    banner_id gacha_banners.id%TYPE;
    rarity_id gacha_rarities.id%TYPE;
    result gacha_card_types%ROWTYPE;
  BEGIN
    SELECT validate_manage_gacha(credential, session_lifetime)
    INTO user_id;

    SELECT id INTO banner_id
    FROM gacha_banners
    WHERE gacha_banners.slug = given_banner_slug;
    IF banner_id is NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Banner not found.';
    END IF;

    SELECT id INTO rarity_id
    FROM gacha_rarities
    WHERE gacha_rarities.slug = given_rarity_slug;
    IF rarity_id is NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Rarity not found.';
    END IF;

    INSERT INTO gacha_card_types
      (name, description, image, rarity, layout, banner, creator)
    VALUES
      (given_name, given_description, add_object('card'::ObjectType, given_image), rarity_id, given_layout, banner_id, user_id)
    RETURNING gacha_card_types.* INTO result;

    INSERT INTO gacha_credits (card_type, "user", name, reason)
    SELECT
      result.id,
      users.id,
      add_credits.name,
      add_credits.reason
    FROM
      unnest(credits) AS add_credits(reason, "user", name) LEFT JOIN
      users ON add_credits."user" = users.slug;

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'GachaAddBanner',
        'user_id', user_id,
        'card_type_id', result.id
      )
    );

    RETURN result;
  END;
$$;

DROP FUNCTION IF EXISTS gacha_edit_card_type CASCADE;
CREATE FUNCTION gacha_edit_card_type (
  credential JSONB,
  session_lifetime INTERVAL,
  banner_slug gacha_banners.slug%TYPE,
  card_type_id gacha_card_types.id%TYPE,
  old_version gacha_card_types.version%TYPE,
  given_name gacha_card_types."name"%TYPE,
  given_description gacha_card_types.description%TYPE,
  given_image objects.url%TYPE,
  given_rarity_slug gacha_rarities.slug%TYPE,
  given_layout gacha_card_types.layout%TYPE,
  given_retired gacha_card_types.retired%TYPE,
  remove_credits RemoveCredit[],
  edit_credits EditCredit[],
  add_credits AddCredit[]
) RETURNS gacha_card_types LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    banner_id gacha_banners.id%TYPE;
    rarity_id gacha_rarities.id%TYPE;
    result gacha_card_types%ROWTYPE;
  BEGIN
    SELECT validate_manage_gacha(credential, session_lifetime) INTO user_id;

    SELECT id INTO banner_id
    FROM gacha_banners
    WHERE gacha_banners.slug = banner_slug;
    IF banner_id is NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Banner not found.';
    END IF;

    IF given_rarity_slug IS NOT NULL THEN
      SELECT id INTO rarity_id
      FROM gacha_rarities
      WHERE gacha_rarities.slug = given_rarity_slug;
      IF rarity_id is NULL THEN
        RAISE EXCEPTION USING
          ERRCODE = 'NTFND',
          MESSAGE = 'Rarity not found.';
      END IF;
    ELSE
      rarity_id = NULL;
    END IF;

    DELETE FROM gacha_credits
    USING unnest(remove_credits) AS credits(id, version)
    WHERE
      gacha_credits.card_type = card_type_id AND
      gacha_credits.id = credits.id AND
      gacha_credits.version = credits.version;

    UPDATE gacha_credits SET
      version = credits.version + 1,
      reason = coalesce(credits.reason, gacha_credits.reason),
      name = CASE
        WHEN users.id IS NULL THEN coalesce(credits.name, gacha_credits.name)
        ELSE NULL
      END,
      "user" = CASE
        WHEN credits.name IS NULL THEN coalesce(users.id, gacha_credits."user")
        ELSE NULL
      END
    FROM
      unnest(edit_credits) AS credits(id, reason, "user", name, version) LEFT JOIN
      users ON credits."user" = users.slug
    WHERE gacha_credits.card_type = card_type_id AND gacha_credits.id = credits.id;

    INSERT INTO gacha_credits (card_type, "user", name, reason)
    SELECT
      card_type_id,
      users.id,
      credits.name,
      credits.reason
    FROM
      unnest(add_credits) AS credits(reason, "user", name) LEFT JOIN
      users ON credits."user" = users.slug;

    UPDATE gacha_card_types SET
      version = old_version + 1,
      name = coalesce(given_name, name),
      description = coalesce(given_description, description),
      image = update_object('card'::ObjectType, image, given_image),
      rarity = coalesce(rarity_id, rarity),
      layout = coalesce(given_layout, layout),
      retired = coalesce(given_retired, retired)
    WHERE gacha_card_types.id = card_type_id AND banner = banner_id
    RETURNING gacha_card_types.* INTO result;

    IF FOUND THEN
      INSERT INTO audit_logs (event) VALUES (
        jsonb_build_object(
          'event', 'GachaEditCardType',
          'user_id', user_id,
          'banner_slug', banner_slug,
          'card_type_id', card_type_id,
          'from_version', old_version
        )
      );
      RETURN result;
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Card type not found.';
    END IF;
  END;
$$;

DROP FUNCTION IF EXISTS gacha_get_balance CASCADE;
CREATE FUNCTION gacha_get_balance (
  credential JSONB,
  session_lifetime INTERVAL
) RETURNS users LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    result_user users%ROWTYPE;
  BEGIN
    SELECT validate_credentials(credential, session_lifetime) INTO user_id;
    SELECT users.* INTO result_user FROM users WHERE users.id = user_id;
    RETURN result_user;
  END;
$$;

DROP FUNCTION IF EXISTS gacha_set_highlight CASCADE;
CREATE FUNCTION gacha_set_highlight (
  credential JSONB,
  session_lifetime INTERVAL,
  card_id gacha_cards.id%TYPE,
  highlight BOOLEAN
) RETURNS gacha_card_highlights LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    card_highlight gacha_card_highlights%ROWTYPE;
  BEGIN
    SELECT validate_credentials(credential, session_lifetime) INTO user_id;

    IF highlight THEN
      INSERT INTO gacha_card_highlights (card, owner, "order")
      SELECT
       target.card,
       target.owner,
       coalesce(max(existing."order"), 0) + 1
      FROM
        (VALUES ( card_id, user_id )) AS target (card, owner) LEFT JOIN
        gacha_card_highlights AS existing ON existing.owner = user_id
      GROUP BY target.card, target.owner, existing.owner
      RETURNING gacha_card_highlights.* INTO card_highlight;
    ELSE
      DELETE FROM gacha_card_highlights AS highlights
      WHERE
        highlights.owner = user_id AND
        highlights.card = card_id
      RETURNING highlights.* INTO card_highlight;
    END IF;

    RETURN card_highlight;
  END;
$$;

DROP FUNCTION IF EXISTS gacha_edit_highlight CASCADE;
CREATE FUNCTION gacha_edit_highlight (
  credential JSONB,
  session_lifetime INTERVAL,
  card_id gacha_cards.id%TYPE,
  given_message gacha_card_highlights.message%TYPE,
  remove_message BOOLEAN
) RETURNS gacha_card_highlights LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    card_highlight gacha_card_highlights%ROWTYPE;
  BEGIN
    SELECT validate_credentials(credential, session_lifetime) INTO user_id;

    UPDATE gacha_card_highlights AS highlights
    SET
     message = CASE
       WHEN remove_message THEN NULL
       ELSE coalesce(given_message, message)
     END
    WHERE highlights.owner = user_id AND highlights.card = card_id
    RETURNING highlights.* INTO card_highlight;

    RETURN card_highlight;
  END;
$$;

DROP FUNCTION IF EXISTS gacha_reorder_highlights CASCADE;
CREATE FUNCTION gacha_reorder_highlights (
  credential JSONB,
  session_lifetime INTERVAL,
  new_order INT[] -- gacha_cards.id%TYPE[]
) RETURNS SETOF gacha_card_highlights LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
  BEGIN
    SELECT validate_credentials(credential, session_lifetime) INTO user_id;

    SET CONSTRAINTS gacha_card_highlights_order_per_user DEFERRED;

    RETURN QUERY
      UPDATE gacha_card_highlights AS highlights
      SET
       "order" = new_order."order"
      FROM (
        SELECT
          card,
          row_number() OVER () AS "order"
        FROM unnest(new_order) AS new_order(card)
      ) AS new_order
      WHERE highlights.owner = user_id AND highlights.card = new_order.card
      RETURNING highlights.*;

    SET CONSTRAINTS gacha_card_highlights_order_per_user IMMEDIATE;
  END;
$$;

DROP FUNCTION IF EXISTS gacha_recycle_card CASCADE;
CREATE FUNCTION gacha_recycle_card (
  credential JSONB,
  session_lifetime INTERVAL,
  scrap_per_roll users.scrap%TYPE,
  card_id gacha_cards.id%TYPE
) RETURNS users LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    card_type_id gacha_card_types.id%TYPE;
    resulting_scrap users.scrap%TYPE;
    result_user users%ROWTYPE;
  BEGIN
    SELECT validate_credentials(credential, session_lifetime) INTO user_id;

    DELETE FROM gacha_cards AS cards
    WHERE cards.owner = user_id AND cards.id = card_id
    RETURNING cards.type INTO card_type_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Card not found.';
    END IF;

    SELECT recycle_scrap_value INTO resulting_scrap
    FROM gacha_rarities INNER JOIN gacha_card_types ON gacha_rarities.id = gacha_card_types.rarity
    WHERE gacha_card_types.id = card_type_id;

    UPDATE users
    SET
      scrap = (scrap + resulting_scrap) % scrap_per_roll,
      rolls = rolls + ((scrap + resulting_scrap) / scrap_per_roll)
    WHERE users.id = user_id
    RETURNING users.* INTO result_user;

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'GachaRecycleCard',
        'user_id', user_id,
        'card_id', card_id,
        'resulting_scrap', resulting_scrap
      )
    );

    RETURN result_user;
  END;
$$;

DROP FUNCTION IF EXISTS gacha_gift_self_made CASCADE;
CREATE FUNCTION gacha_gift_self_made (
  credential JSONB,
  session_lifetime INTERVAL,
  gift_to_user_slug users.slug%TYPE,
  banner_slug gacha_banners.slug%TYPE,
  card_type gacha_card_types.id%TYPE
) RETURNS gacha_cards LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    gift_to_user_id users.id%TYPE;
    new_card gacha_cards%ROWTYPE;
    banner_correct BOOL = FALSE;
  BEGIN
    IF acting_as_slug(credential) = gift_to_user_slug THEN
      SELECT validate_credentials(credential, session_lifetime) INTO user_id;
    ELSE
      SELECT validate_manage_gacha(credential, session_lifetime) INTO user_id;
    END IF;

    SELECT id INTO gift_to_user_id FROM users WHERE slug = gift_to_user_slug;
    IF gift_to_user_id IS NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Gift target user not found.';
    END IF;

    SELECT
      TRUE INTO banner_correct
    FROM
      gacha_banners INNER JOIN
      gacha_card_types ON gacha_banners.id = gacha_card_types.banner
    WHERE gacha_banners.slug = banner_slug;

    IF NOT banner_correct THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Card type not found in banner.';
    END IF;

    INSERT INTO gacha_cards (owner, type)
    VALUES (gift_to_user_id, card_type)
    RETURNING gacha_cards.* INTO new_card;

    INSERT INTO gacha_card_qualities (card, quality)
    SELECT new_card.id, gacha_qualities.id
    FROM gacha_qualities WHERE gacha_qualities.slug = 'self';

    INSERT INTO notifications ("for", notification) VALUES(
      gift_to_user_id,
      jsonb_build_object(
        'type', 'GachaGiftedCard',
        'reason', 'SelfMade',
        'banner', banner_slug,
        'card', new_card.id
      )
    );

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'GachaGiftSelfMade',
        'user_id', user_id,
        'card_type', card_type,
        'gift_to_user_slug', gift_to_user_slug
      )
    );

    RETURN new_card;
  END;
$$;

DROP FUNCTION IF EXISTS gacha_forge_card_type CASCADE;
CREATE FUNCTION gacha_forge_card_type (
  credential JSONB,
  session_lifetime INTERVAL,
  card_name gacha_card_types.name%TYPE,
  card_image_object_name objects.name%TYPE,
  card_image_url objects.url%TYPE,
  card_image_source_url objects.source_url%TYPE,
  card_quote gacha_card_types.description%TYPE,
  card_rarity_slug gacha_rarities.slug%TYPE
) RETURNS gacha_card_types LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    rarity_id gacha_rarities.id%TYPE;
    new_card_type gacha_card_types%ROWTYPE;
    banner_slug gacha_banners.slug%TYPE = 'jads';
    banner_id gacha_banners.id%TYPE;
    free BOOL = TRUE;
  BEGIN
    SELECT validate_credentials(credential, session_lifetime) INTO user_id;

    SELECT
      FALSE INTO free
    FROM
      gacha_card_types
    WHERE
      forged_by = user_id AND
      retired = FALSE
    LIMIT 1;

    IF NOT free THEN
      DECLARE
        violation TEXT;
      BEGIN
        UPDATE jasb.users SET
          rolls = rolls - 1
        WHERE id = user_id;
      EXCEPTION
        WHEN UNIQUE_VIOLATION THEN
          GET STACKED DIAGNOSTICS violation := CONSTRAINT_NAME;
          IF violation = 'gacha_balance_not_negative' THEN
            RAISE EXCEPTION USING
              ERRCODE = 'BDREQ',
              MESSAGE = 'Can‘t afford to forge a card.';
          ELSE
            RAISE;
          END IF;
      END;
    END IF;

    SELECT id into banner_id FROM gacha_banners WHERE slug = banner_slug;
    IF banner_id IS NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Banner not found.';
    END IF;
    SELECT id into rarity_id FROM gacha_rarities WHERE slug = card_rarity_slug;
    IF rarity_id IS NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Rarity not found.';
    END IF;

    INSERT INTO gacha_card_types (name, image, rarity, banner, creator, description, forged_by)
    VALUES (
      card_name,
      named_object('card'::ObjectType, card_image_object_name, card_image_url, card_image_source_url),
      rarity_id,
      banner_id,
      user_id,
      card_quote,
      user_id
    )
    RETURNING gacha_card_types.* INTO new_card_type;

    INSERT INTO gacha_credits (card_type, "user", name, reason)
    VALUES (
      new_card_type.id,
      user_id,
      NULL,
      'Forged By'
    );

    PERFORM gacha_gift_self_made(
      credential,
      session_lifetime,
      acting_as_slug(credential),
      banner_slug,
      new_card_type.id
    );

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'ForgeCardType',
        'user_id', user_id,
        'name', card_name,
        'image', card_image_source_url,
        'quote', card_quote,
        'rarity', card_rarity_slug,
        'card_type', new_card_type.id
      )
    );

    RETURN new_card_type;
  END;
$$;

DROP FUNCTION IF EXISTS gacha_retire_forged CASCADE;
CREATE FUNCTION gacha_retire_forged (
  credential JSONB,
  session_lifetime INTERVAL,
  card_type_id gacha_card_types.id%TYPE
) RETURNS gacha_card_types LANGUAGE plpgsql AS $$
  DECLARE
    user_id users.id%TYPE;
    new_card_type gacha_card_types%ROWTYPE;
  BEGIN
    SELECT validate_credentials(credential, session_lifetime) INTO user_id;

    UPDATE gacha_card_types SET
      retired = TRUE,
      version = version + 1
    WHERE
      forged_by = user_id AND
      retired = FALSE AND
      id = card_type_id
    RETURNING gacha_card_types.* INTO new_card_type;
    IF new_card_type.id IS NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = 'NTFND',
        MESSAGE = 'Forged card type not found, not yours to retire, or already retired.';
    END IF;

    INSERT INTO audit_logs (event) VALUES (
      jsonb_build_object(
        'event', 'RetireForgedCardType',
        'user_id', user_id,
        'card_type', card_type_id
      )
    );

    RETURN new_card_type;
  END;
$$;

CREATE OR REPLACE FUNCTION update_next_issue_number()
RETURNS TRIGGER AS $$
  BEGIN
    SELECT next_issue_number INTO NEW.issue_number FROM jasb.gacha_card_types_meta WHERE type = NEW.type;
    IF NEW.issue_number IS NULL THEN
      NEW.issue_number = 0;
    END IF;
    INSERT INTO jasb.gacha_card_types_meta AS card_types_meta (type, next_issue_number) VALUES (NEW.type, 1)
    ON CONFLICT ON CONSTRAINT gacha_card_types_meta_pkey DO
      UPDATE SET next_issue_number = card_types_meta.next_issue_number + 1;
    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER update_next_issue_number_trigger BEFORE INSERT ON jasb.gacha_cards
  FOR EACH ROW EXECUTE FUNCTION update_next_issue_number();
