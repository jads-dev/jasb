INSERT INTO gacha_credits (card_type, "user", name, reason)
SELECT types.id, types.forged_by, NULL, 'Forged By'
FROM gacha_card_types AS types
WHERE types.forged_by IS NOT NULL;
