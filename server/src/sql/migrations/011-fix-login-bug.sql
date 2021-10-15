CREATE OR REPLACE FUNCTION jasb.login(
  user_id users.id%TYPE,
  given_session sessions.session%TYPE,
  given_name users.name%TYPE,
  given_discriminator users.discriminator%TYPE,
  given_avatar users.avatar%TYPE,
  given_access_token sessions.access_token%TYPE,
  given_refresh_token sessions.refresh_token%TYPE,
  discord_expires_in INTERVAL,
  initial_balance users.balance%TYPE
)
  RETURNS SETOF jasb.sessions
  LANGUAGE PLPGSQL
AS $$
  DECLARE
    new_user BOOLEAN;
  BEGIN
    INSERT INTO
      jasb.users (id, name, discriminator, avatar, balance)
    VALUES (
      user_id,
      given_name,
      given_discriminator,
      given_avatar,
      initial_balance
    )
    ON CONFLICT ON CONSTRAINT users_pkey DO UPDATE SET
      name = excluded.name,
      discriminator = excluded.discriminator,
      avatar = excluded.avatar
    RETURNING (xmax = 0) INTO new_user;

    RETURN QUERY
      INSERT INTO jasb.sessions ("user", session, access_token, refresh_token, discord_expires)
      VALUES (
        user_id,
        given_session,
        given_access_token,
        given_refresh_token,
        (NOW() + discord_expires_in)
      ) RETURNING *;

    IF new_user THEN
      INSERT INTO jasb.audit_logs ("user", event) VALUES (
        user_id,
        json_build_object(
          'event', 'CreateAccount',
          'balance', initial_balance
        )
      );
      INSERT INTO jasb.notifications ("for", notification) VALUES (
        user_id,
        json_build_object(
          'type', 'Gifted',
          'amount', initial_balance,
          'reason', 'AccountCreated'
        )
      );
    END IF;
  END;
$$;
