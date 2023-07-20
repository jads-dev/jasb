CREATE TYPE BetProgress AS ENUM('Voting', 'Locked', 'Complete', 'Cancelled');

CREATE TYPE GameProgress AS ENUM('Future', 'Current', 'Finished');

CREATE OR REPLACE FUNCTION update_version() RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
  BEGIN
    IF NEW.version != (OLD.version + 1) THEN
      RAISE EXCEPTION USING
        ERRCODE = 'CONFL',
        MESSAGE = 'Version mismatch (expected ' || OLD.version + 1 || ', got ' || NEW.version || ').';
    END IF;
    NEW.modified := now();
    RETURN NEW;
  END
$$;

CREATE TABLE
  games (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slug TEXT NOT NULL CONSTRAINT unique_game_slug UNIQUE,
    "name" TEXT NOT NULL,
    cover TEXT NOT NULL,
    started DATE,
    finished DATE,
    progress GameProgress GENERATED ALWAYS AS (
      CASE
        WHEN (
          (started IS NULL)
          AND (finished IS NULL)
        ) THEN 'Future'::GameProgress
        WHEN (
          (started IS NOT NULL)
          AND (finished IS NULL)
        ) THEN 'Current'::GameProgress
        WHEN (
          (started IS NOT NULL)
          AND (finished IS NOT NULL)
        ) THEN 'Finished'::GameProgress
        ELSE NULL::GameProgress
      END
    ) STORED NOT NULL,
    "order" INT,
    created TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    "version" INT DEFAULT 0 NOT NULL,
    modified TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT started_if_finished CHECK (
      NOT (
        (started IS NULL)
        AND (finished IS NOT NULL)
      )
    )
  );

CREATE INDEX bet_progress ON games (progress);

CREATE INDEX future_game_order 
  ON games ("order" NULLS LAST, created)
  WHERE progress = 'Future'::GameProgress;

CREATE INDEX current_game_order 
  ON games (started, created) 
  WHERE progress = 'Current'::GameProgress;

CREATE INDEX finished_game_order 
  ON games (finished DESC, created) 
  WHERE progress = 'Finished'::GameProgress;

CREATE TRIGGER update_game_version BEFORE UPDATE ON games
  FOR EACH ROW EXECUTE PROCEDURE update_version ();

CREATE TABLE
  lock_moments (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slug TEXT NOT NULL,
    game INT REFERENCES games (id) ON DELETE CASCADE,
    "name" TEXT NOT NULL,
    "order" INT NOT NULL,
    created TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    "version" INT DEFAULT 0 NOT NULL,
    modified TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE (game, id), -- Used as a foreign key, to ensure game matches between bet and lock moment.
    CONSTRAINT unique_lock_moment_order_in_game UNIQUE (game, "order") DEFERRABLE INITIALLY IMMEDIATE,
    CONSTRAINT unique_lock_moment_slug_in_game UNIQUE (game, slug)
  );

CREATE TRIGGER update_lock_moment_version BEFORE UPDATE ON lock_moments
  FOR EACH ROW EXECUTE PROCEDURE update_version();

CREATE INDEX lock_moment_game ON lock_moments (game);

CREATE TABLE
  avatars (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    discord_user TEXT,
    hash TEXT,
    default_index INT CONSTRAINT unique_default_avatar UNIQUE,
    url TEXT NOT NULL,
    cached BOOLEAN DEFAULT FALSE NOT NULL,
    CONSTRAINT unique_hash_per_user UNIQUE (discord_user, hash),
    CONSTRAINT hash_xor_index CHECK (
      (discord_user IS NULL AND hash IS NULL AND default_index IS NOT NULL) OR
      (discord_user IS NOT NULL AND hash IS NOT NULL AND default_index IS NULL)
    )
  );

CREATE TABLE
  users (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    discord_id TEXT NOT NULL CONSTRAINT unique_discord_id UNIQUE,
    slug TEXT NOT NULL GENERATED ALWAYS AS (CASE WHEN discriminator IS NULL THEN '@' || username ELSE discord_id END) STORED CONSTRAINT unique_user_slug UNIQUE,
    username TEXT NOT NULL,
    display_name TEXT,
    name TEXT NOT NULL GENERATED ALWAYS AS (coalesce(display_name, username)) STORED,
    discriminator TEXT,
    created TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    balance INT NOT NULL,
    avatar INT NOT NULL REFERENCES avatars (id)
  );

CREATE TABLE
  sessions (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "user" INT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    "session" TEXT NOT NULL,
    started TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    access_token TEXT NOT NULL,
    refresh_token TEXT NOT NULL,
    discord_expires TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT unique_session_per_user UNIQUE ("user", "session")
  );

CREATE INDEX session_started ON sessions (started);

CREATE TABLE
  bets (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    game INT REFERENCES games (id) ON DELETE CASCADE,
    slug TEXT NOT NULL,
    "name" TEXT NOT NULL,
    description TEXT NOT NULL,
    spoiler BOOLEAN NOT NULL,
    author INT NOT NULL REFERENCES users (id),
    lock_moment INT NOT NULL REFERENCES lock_moments (id),
    progress BetProgress NOT NULL,
    cancelled_reason TEXT,
    resolved TIMESTAMP WITH TIME ZONE,
    created TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    "version" INT DEFAULT 0 NOT NULL,
    modified TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT unique_bet_slug_per_game UNIQUE (game, slug),
    FOREIGN KEY (game, lock_moment) REFERENCES lock_moments (game, id),
    CONSTRAINT reason_when_cancelled CHECK (
      (
        (cancelled_reason IS NOT NULL)
        AND (progress = 'Cancelled'::BetProgress)
      )
      OR (
        (cancelled_reason IS NULL)
        AND (progress <> 'Cancelled'::BetProgress)
      )
    ),
    CONSTRAINT resolved_when_necessary CHECK (
      (
        (resolved IS NULL)
        AND (
          progress = ANY (
            ARRAY[
              'Voting'::BetProgress,
              'Locked'::BetProgress
            ]
          )
        )
      )
      OR (
        (resolved IS NOT NULL)
        AND (
          progress = ANY (
            ARRAY[
              'Complete'::BetProgress,
              'Cancelled'::BetProgress
            ]
          )
        )
      )
    )
  );

CREATE INDEX bet_game ON bets (game);

CREATE TRIGGER update_bet_version BEFORE UPDATE ON bets
  FOR EACH ROW EXECUTE PROCEDURE update_version();

CREATE TABLE
  options (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    slug TEXT NOT NULL,
    bet INT REFERENCES bets (id) ON DELETE CASCADE,
    "name" TEXT NOT NULL,
    image TEXT,
    won BOOLEAN DEFAULT FALSE NOT NULL,
    "order" INT NOT NULL,
    created TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    "version" INT DEFAULT 0 NOT NULL,
    modified TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT options_order UNIQUE (bet, "order") DEFERRABLE INITIALLY IMMEDIATE
  );

CREATE INDEX option_bet ON options (bet);

CREATE TRIGGER update_option_version BEFORE UPDATE ON options
  FOR EACH ROW EXECUTE PROCEDURE update_version ();

CREATE TABLE
  stakes (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "option" INT REFERENCES options (id) ON DELETE CASCADE,
    "owner" INT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    made_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    amount INT NOT NULL,
    message TEXT,
    payout INT,
    CONSTRAINT single_stake_per_option UNIQUE ("option", "owner"),
    CONSTRAINT positive_amount CHECK (amount > 0)
  );

CREATE INDEX stake_order ON stakes ("option", made_at);

CREATE TABLE
  general_permissions (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "user" INT NOT NULL REFERENCES users (id) ON DELETE CASCADE CONSTRAINT one_general_permissions_per_user UNIQUE,
    manage_games BOOLEAN NOT NULL,
    manage_permissions BOOLEAN NOT NULL,
    manage_bets BOOLEAN NOT NULL
  );

CREATE TABLE
  specific_permissions (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    game INT NOT NULL REFERENCES games (id) ON DELETE CASCADE,
    "user" INT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    manage_bets BOOLEAN NOT NULL,
    CONSTRAINT one_specific_permissions_per_game_per_user UNIQUE (game, "user")
  );

CREATE TABLE
  notifications (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "for" INT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    happened TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    notification JSONB NOT NULL,
    "read" BOOLEAN DEFAULT FALSE NOT NULL
  );

CREATE INDEX notifications_order ON notifications ("for", happened DESC);

CREATE TABLE audit_logs (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  happened TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  event JSONB NOT NULL
);

CREATE TYPE AddOption AS (
  slug TEXT,
  "name" TEXT,
  image TEXT,
  "order" INTEGER
);

CREATE TYPE EditOption AS (
  slug TEXT,
  "version" INTEGER,
  "name" TEXT,
  image TEXT,
  remove_image BOOLEAN,
  "order" INTEGER
);

CREATE TYPE RemoveOption AS (
  slug TEXT,
  "version" INTEGER
);

CREATE TYPE AddLockMoment AS (
  slug TEXT,
  "name" TEXT,
  "order" INTEGER
);

CREATE TYPE EditLockMoment AS (
  slug TEXT,
  "version" INTEGER,
  "name" TEXT,
  "order" INTEGER
);

CREATE TYPE RemoveLockMoment AS (
  slug TEXT,
  "version" INTEGER
);