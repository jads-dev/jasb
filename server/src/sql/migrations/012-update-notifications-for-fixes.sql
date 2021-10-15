UPDATE jasb.notifications
SET
  notification = jsonb_insert(
    notification-'balance',
    ARRAY['amount'],
    notification->'balance'
    )
WHERE notification->'type' = '"Gifted"'::jsonb AND notification?'balance';
