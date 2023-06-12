import type * as Joda from "@js-joda/core";
import { StatusCodes } from "http-status-codes";
import { default as Pg } from "pg";
import { migrate } from "postgres-migrations";
import { default as Slonik, type SerializableValue } from "slonik";
import { z } from "zod";

import {
  AvatarCache,
  Bets,
  ExternalNotifier,
  Feed,
  Games,
  Notifications,
  Stakes,
  Users,
} from "../internal.js";
import type { Config } from "../server/config.js";
import { WebError } from "../server/errors.js";
import type { Logging } from "../server/logging.js";
import { Notifier } from "../server/notifier.js";
import { SecretToken } from "../util/secret-token.js";
import type { ObjectUploader } from "./object-upload.js";

const createResultParserInterceptor = (): Slonik.Interceptor => {
  return {
    transformRow: (executionContext, actualQuery, row) => {
      const { resultParser } = executionContext;

      if (!resultParser) {
        return row;
      }

      const validationResult = resultParser.safeParse(row);

      if (!validationResult.success) {
        throw new Slonik.SchemaValidationError(
          actualQuery,
          row as unknown as SerializableValue[],
          validationResult.error.issues,
        );
      }

      return validationResult.data as Slonik.QueryResultRow;
    },
  };
};

const sqlFragment = Slonik.sql.fragment;
const typedSql = Slonik.createSqlTag({
  typeAliases: {
    void: z.object({}).strict(),
    boolean: z
      .object({
        result: z.boolean(),
      })
      .strict(),
    user: Users.User,
    user_permissions_stats: Users.User.merge(Users.Permissions).merge(
      Users.BetStats,
    ),
    session: Users.LoginDetail,
    login: Users.User.merge(Users.Permissions).merge(Users.BetStats),
    netWorthLeaderboard: Users.User.merge(Users.Leaderboard).merge(
      Users.BetStats,
    ),
    debtLeaderboard: Users.User.merge(Users.Leaderboard),
    bankruptcy_stats: Users.BankruptcyStats,
    notification: Notifications.Notification,
    access_token: Users.AccessToken,
    game: Games.Game,
    game_with_details: Games.Game.merge(Games.BetStats)
      .merge(Games.StakeStats)
      .merge(Games.Mods),
    game_with_stats: Games.Game.merge(Games.BetStats),
    bet_with_options: Bets.Bet.merge(Bets.WithOptions),
    lock_status: Bets.LockStatus,
    game_with_bets: Games.Game.merge(Games.EmbeddedBets),
    bet_with_options_and_author: Bets.Bet.merge(Bets.WithOptions).merge(
      Bets.Author,
    ),
    game_name: Games.Name,
    bet_complete: ExternalNotifier.BetComplete,
    new_balance: Stakes.NewBalance,
    new_stake: ExternalNotifier.NewStake,
    feed_item: Feed.Item,
    per_game_permission: Users.PerGamePermissions,
    avatar_cache_url: AvatarCache.Url,
    avatar_cache_details: AvatarCache.CacheDetails,
  },
}).typeAlias;

export class Store {
  readonly logger: Logging.Logger;
  readonly config: Config.Server;
  readonly notifier: Notifier;
  readonly avatarCache: ObjectUploader | undefined;
  readonly pool: Slonik.DatabasePool;

  private static connectionString({
    host,
    port,
    database,
    user,
    password,
    ssl,
  }: Config.PostgresData): string {
    return Slonik.stringifyDsn({
      applicationName: "jasb",
      host: host,
      port: port,
      databaseName: database,
      username: user,
      password: password?.value,
      sslMode: ssl,
    });
  }

  private constructor(
    logger: Logging.Logger,
    config: Config.Server,
    notifier: Notifier,
    avatarCache: ObjectUploader | undefined,
    pool: Slonik.DatabasePool,
  ) {
    this.logger = logger;
    this.config = config;
    this.notifier = notifier;
    this.avatarCache = avatarCache;
    this.pool = pool;
  }

  public static async load(
    logger: Logging.Logger,
    config: Config.Server,
    notifier: Notifier,
    avatarCache: ObjectUploader | undefined,
  ): Promise<Store> {
    const store = new Store(
      logger.child({
        system: "store",
        store: "postgres",
      }),
      config,
      notifier,
      avatarCache,
      await Slonik.createPool(Store.connectionString(config.store.source), {
        typeParsers: [
          { name: "int8", parse: (v) => Number.parseInt(v, 10) },
          { name: "timestamptz", parse: (v) => v },
        ],
        interceptors: [createResultParserInterceptor()],
      }),
    );
    await store.migrate();
    return store;
  }

  private async migrate(): Promise<void> {
    const client = new Pg.Client(
      Store.connectionString(this.config.store.source),
    );
    await client.connect();
    const migrationLogger = this.logger.child({
      task: "migration",
    });
    await migrate({ client }, "./src/sql/migrations", {
      logger: (msg) => migrationLogger.info(msg),
    });
  }

  async validateAdminOrMod(
    id: string,
    sessionId: SecretToken,
  ): Promise<string> {
    return await this.withClient(async (client) => {
      const sql = typedSql("boolean");
      await client.query(sql`
        SELECT
          validate_admin_or_mod AS result
        FROM
          jasb.validate_admin_or_mod(
            ${id},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()}
          );
      `);
      return id;
    });
  }

  async getUser(
    id: string,
    sessionId?: SecretToken,
  ): Promise<(Users.User & Users.Permissions & Users.BetStats) | undefined> {
    return await this.withClient(async (client) => {
      if (sessionId !== undefined) {
        const sql = typedSql("boolean");
        await client.query(sql`
          SELECT
            validate_session AS result
          FROM
            jasb.validate_session(
              ${id},
              ${sessionId.uri},
              ${this.config.auth.sessionLifetime.toString()}
            );
        `);
      }
      const sql = typedSql("user_permissions_stats");
      const result = await client.maybeOne(sql`
        SELECT
          users.*,
          (users.staked + users.balance) AS net_worth,
          COALESCE(ARRAY_AGG(perm.game) FILTER (WHERE perm.game IS NOT NULL), '{}') AS moderator_for
        FROM
          jasb.users_with_stakes AS users LEFT JOIN 
          permissions AS perm ON users.id = perm."user" AND manage_bets = TRUE
        WHERE
          users.id = ${id}
        GROUP BY (
          users.id,
          users.name,
          users.discriminator,
          users.avatar,
          users.created,
          users.admin,
          users.balance,
          users.staked,
          users.avatar_cache
        );
      `);
      return result ?? undefined;
    });
  }

  async getNetWorthLeaderboard(): Promise<
    readonly (Users.User & Users.BetStats & Users.Leaderboard)[]
  > {
    return await this.withClient(async (client) => {
      const sql = typedSql("netWorthLeaderboard");
      const results = await client.query(sql`
        SELECT
          id,
          name,
          discriminator,
          avatar,
          avatar_cache,
          created,
          admin,
          balance,
          staked,
          net_worth,
          rank::INT
        FROM
          jasb.leaderboard
        WHERE
          net_worth > ${this.config.rules.initialBalance}
        ORDER BY rank
        LIMIT 100;
      `);
      return results.rows;
    });
  }

  async getDebtLeaderboard(): Promise<
    readonly (Users.User & Users.Leaderboard)[]
  > {
    return await this.withClient(async (client) => {
      const sql = typedSql("debtLeaderboard");
      const results = await client.query(sql`
        SELECT
          id,
          name,
          discriminator,
          avatar,
          avatar_cache,
          created,
          admin,
          balance,
          RANK() OVER (
            ORDER BY balance ASC
          ) rank
        FROM 
          jasb.users
        WHERE
          balance < 0
        ORDER BY balance ASC
        LIMIT 100;
      `);
      return results.rows;
    });
  }

  async bankruptcyStats(userId: string): Promise<Users.BankruptcyStats> {
    return await this.withClient(async (client) => {
      const sql = typedSql("bankruptcy_stats");
      return await client.one(sql`
        SELECT
          COALESCE(SUM(stakes.amount), 0) AS amount_lost,
          COALESCE(COUNT(*), 0) AS stakes_lost,
          COALESCE(SUM(stakes.amount) FILTER (WHERE bets.progress = 'Locked'), 0) AS locked_amount_lost,
          COALESCE(COUNT(*) FILTER (WHERE bets.progress = 'Locked'), 0) AS locked_stakes_lost,
          ${this.config.rules.initialBalance}::INT AS balance_after
        FROM
          jasb.stakes LEFT JOIN 
          jasb.bets ON bets.id = stakes.bet AND bets.game = stakes.game
        WHERE
          stakes.owner = ${userId} AND 
          is_active(bets.progress)
      `);
    });
  }

  async bankrupt(userId: string, sessionId: SecretToken): Promise<Users.User> {
    return await this.inTransaction(async (client) => {
      const sql = typedSql("user");
      return await client.one(sql`
        SELECT
          id,
          name,
          discriminator,
          avatar,
          avatar_cache
          created,
          admin,
          balance
        FROM
          jasb.bankrupt(
            ${userId},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${this.config.rules.initialBalance}
          );
      `);
    });
  }

  async login(
    userId: string,
    name: string,
    discriminator: string | null,
    avatar: string | null,
    accessToken: string,
    refreshToken: string,
    discordExpiresIn: Joda.Duration,
  ): Promise<{
    user: Users.User & Users.Permissions & Users.BetStats & Users.LoginDetail;
    notifications: readonly Notifications.Notification[];
  }> {
    const sessionId = await SecretToken.secureRandom(
      this.config.auth.sessionIdSize,
    );
    return await this.inTransaction(async (client) => {
      const createSession = async () => {
        const sql = typedSql("session");
        return await client.one(sql`SELECT session, started FROM jasb.login(
          ${userId},
          ${sessionId.uri},
          ${name},
          ${discriminator},
          ${avatar},
          ${accessToken},
          ${refreshToken},
          ${discordExpiresIn.toString()},
          ${this.config.rules.initialBalance}
        )`);
      };
      const login = async () => {
        const session = await createSession();
        const sql = typedSql("login");
        const user = await client.one(sql`
          SELECT
            users.*,
            (users.staked + users.balance) AS net_worth,
            COALESCE(ARRAY_AGG(permissions.game) FILTER ( WHERE permissions.game IS NOT NULL ), '{}') AS moderator_for
          FROM
            jasb.users_with_stakes AS users LEFT JOIN
            jasb.permissions ON users.id = permissions."user" AND manage_bets = TRUE
          WHERE users.id = ${userId}
          GROUP BY (
            users.id,
            users.name,
            users.discriminator,
            users.avatar,
            users.avatar_cache,
            users.created,
            users.admin,
            users.balance,
            users.staked
          )
        `);
        return { ...user, ...session };
      };
      const notification = async () => {
        const sql = typedSql("notification");
        return await client.query(sql`
          SELECT
            id,
            TO_JSON(happened) AS happened,
            notification,
            read
          FROM
            jasb.notifications
          WHERE
            "for" = ${userId} AND 
            read = FALSE
          ORDER BY 
            notifications.happened DESC;
        `);
      };
      const [loginResults, notificationResults] = await Promise.all([
        login(),
        notification(),
      ]);
      return {
        user: loginResults,
        notifications: notificationResults.rows,
      };
    });
  }

  async logout(
    userId: string,
    session: SecretToken,
  ): Promise<string | undefined> {
    return await this.withClient(async (client) => {
      const sql = typedSql("access_token");
      const result = await client.maybeOne(sql`
        DELETE FROM
          jasb.sessions
        WHERE
          "user" = ${userId} AND 
          session = ${session.uri}
        RETURNING access_token;
      `);
      return result?.access_token;
    });
  }

  async getGame(
    id: string,
  ): Promise<
    (Games.Game & Games.BetStats & Games.StakeStats & Games.Mods) | undefined
  > {
    return await this.withClient(async (client) => {
      const sql = typedSql("game_with_details");
      return (
        (await client.maybeOne(sql`
          SELECT
            games.id,
            games.name,
            games.cover,
            games.igdb_id,
            games.added,
            games.started,
            games.finished,
            games."order",
            games.version,
            games.modified,
            games.progress,
            COALESCE(bets.bets, 0) AS bets,
            COALESCE(stakes.staked, 0) AS staked,
            TO_JSON(mods.mods) AS mods
          FROM
            jasb.games LEFT JOIN 
            jasb.game_bet_stats AS bets ON games.id = bets.game LEFT JOIN 
            jasb.game_stake_stats AS stakes ON games.id = stakes.game LEFT JOIN 
            jasb.game_mods AS mods ON games.id = mods.game
          WHERE
            id = ${id};
        `)) ?? undefined
      );
    });
  }

  getSort(subset: Games.Progress): Slonik.SqlFragment {
    switch (subset) {
      case "Future":
        return sqlFragment`games."order" ASC NULLS LAST`;
      case "Current":
        return sqlFragment`games.started ASC`;
      case "Finished":
        return sqlFragment`games.finished DESC`;
    }
  }

  async getGames(
    subset: Games.Progress,
  ): Promise<readonly (Games.Game & Games.BetStats)[]> {
    return await this.withClient(async (client) => {
      const sql = typedSql("game_with_stats");
      const results = await client.query(sql`
        SELECT
          games.*,
          game_bet_stats.bets
        FROM
          jasb.games INNER JOIN 
          jasb.game_bet_stats ON game = id
        WHERE
          progress = ${subset}
        ORDER BY
          ${this.getSort(subset)}, games.added ASC;
      `);
      return results.rows;
    });
  }

  async addGame(
    creator: string,
    sessionId: SecretToken,
    id: string,
    name: string,
    cover: string,
    igdbId: string,
    started: string | null,
    finished: string | null,
    order: number | null,
  ): Promise<Games.Game> {
    return await this.withClient(async (client) => {
      const sql = typedSql("game");
      return await client.one(sql`
        SELECT
          *
        FROM
          jasb.add_game(
            ${creator},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${id},
            ${name},
            ${cover},
            ${igdbId},
            ${started},
            ${finished},
            ${order}
          );
      `);
    });
  }

  async editGame(
    editor: string,
    sessionId: SecretToken,
    version: number,
    id: string,
    name?: string,
    cover?: string,
    igdbId?: string,
    started?: string | null,
    finished?: string | null,
    order?: number | null,
  ): Promise<Games.Game & Games.BetStats> {
    return await this.withClient(async (client) => {
      const sql = typedSql("game_with_stats");
      return await client.one(sql`
        SELECT
          games.id,
          games.name,
          games.cover,
          games.igdb_id,
          games.added,
          games.started,
          games.finished,
          games."order",
          games.version,
          games.modified,
          games.progress,
          COALESCE(bets.bets, 0) AS bets
        FROM
          jasb.edit_game(
            ${editor},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${id},
            ${version},
            ${name ?? null},
            ${cover ?? null},
            ${igdbId ?? null},
            ${started ?? null},
            ${started === null},
            ${finished ?? null},
            ${finished === null},
            ${order ?? null},
            ${order === null}
          ) as games LEFT JOIN 
          jasb.game_bet_stats AS bets ON games.id = bets.game;
      `);
    });
  }

  async getBets(
    gameId: string,
  ): Promise<readonly (Bets.Bet & Bets.WithOptions)[]> {
    return await this.withClient(async (client) => {
      const sql = typedSql("bet_with_options");
      const results = await client.query(sql`
        SELECT
          bets.*,
          TO_JSONB(COALESCE(options.options, '{}')) AS options
        FROM
          jasb.bets LEFT JOIN
          jasb.options_by_bet AS options ON bets.game = options.game AND bets.id = options.bet
        WHERE
          bets.game = ${gameId}
        ORDER BY bets.created DESC;
      `);
      return results.rows;
    });
  }

  async getBetsLockStatus(gameId: string): Promise<readonly Bets.LockStatus[]> {
    return await this.withClient(async (client) => {
      const sql = typedSql("lock_status");
      const results = await client.query(sql`
        SELECT
          bets.id,
          bets.name,
          bets.locks_when,
          bets.progress = 'Locked'::BetProgress as locked,
          bets.version
        FROM
          jasb.bets
        WHERE
          bets.game = ${gameId} AND
          (bets.progress = 'Voting'::BetProgress OR bets.progress = 'Locked'::BetProgress)
        ORDER BY bets.created DESC;
      `);
      return results.rows;
    });
  }

  async getUserBets(
    userId: string,
  ): Promise<readonly (Games.Game & Games.EmbeddedBets)[]> {
    return await this.withClient(async (client) => {
      const sql = typedSql("game_with_bets");
      const results = await client.query(sql`
        WITH
          bets AS (
            SELECT
              bets.game,
              bets.id,
              JSONB_INSERT(
                TO_JSONB((bets.*)::jasb.bets),
                ARRAY['options'],
                TO_JSONB(COALESCE(options.options, '{}'))
              ) AS bet,
              MAX(stakes.made_at) AS last_stake_made_at
            FROM
              jasb.stakes INNER JOIN 
              jasb.bets ON stakes.game = bets.game AND stakes.bet = bets.id LEFT JOIN
              jasb.options_by_bet AS options ON bets.game = options.game AND bets.id = options.bet
            WHERE stakes.owner = ${userId}
            GROUP BY (bets.game, bets.id, options.options)
            ORDER BY MAX(stakes.made_at) DESC
            LIMIT 100
          )
          SELECT
            games.*,
            JSONB_AGG(bets.bet) AS bets
          FROM
            bets INNER JOIN
            jasb.games ON bets.game = games.id
          GROUP BY games.id
          ORDER BY MAX(bets.last_stake_made_at) DESC;
      `);
      return results.rows;
    });
  }

  betWithOptionsAndAuthorFromBets(betsSubquery: Slonik.SqlFragment) {
    const sql = typedSql("bet_with_options_and_author");
    return sql`
      SELECT
        bets.game,
        bets.id,
        bets.name,
        bets.description,
        bets.spoiler,
        bets.locks_when,
        bets.cancelled_reason,
        bets.progress,
        bets.created,
        bets.modified,
        bets.version,
        bets.resolved,
        bets.by,
        users.name AS author_name,
        users.discriminator AS author_discriminator,
        users.avatar AS author_avatar,
        TO_JSONB(COALESCE(options.options, '{}')) AS options
      FROM
        (${betsSubquery}) AS bets INNER JOIN 
        jasb.users ON bets.by = users.id LEFT JOIN 
        jasb.options_by_bet AS options ON bets.game = options.game AND bets.id = options.bet;
    `;
  }

  async getBet(
    gameId: string,
    betId: string,
  ): Promise<(Bets.Bet & Bets.WithOptions & Bets.Author) | undefined> {
    return await this.withClient(async (client) => {
      return (
        (await client.maybeOne(
          this.betWithOptionsAndAuthorFromBets(sqlFragment`
          SELECT * FROM jasb.bets WHERE bets.game = ${gameId} AND bets.id = ${betId}
        `),
        )) ?? undefined
      );
    });
  }

  toAddOptionRow({
    id,
    name,
    image,
  }: {
    id: string;
    name: string;
    image: string | null;
  }): Slonik.ValueExpression {
    return sqlFragment`ROW(${id}, ${name ?? null}, ${
      image ?? null
    })::AddOption`;
  }

  async newBet(
    by: string,
    sessionId: SecretToken,
    gameId: string,
    id: string,
    name: string,
    description: string,
    spoiler: boolean,
    locksWhen: string,
    options: {
      id: string;
      name: string;
      image: string | null;
    }[],
  ): Promise<Bets.Bet & Bets.WithOptions & Bets.Author> {
    const optionsArray =
      options !== undefined
        ? sqlFragment`ARRAY[${Slonik.sql.join(
            options.map(this.toAddOptionRow),
            sqlFragment`, `,
          )}]`
        : null;
    return await this.inTransaction(async (client) => {
      const result = await client.one(
        this.betWithOptionsAndAuthorFromBets(sqlFragment`
          SELECT
            *
          FROM
            jasb.add_bet(
              ${by},
              ${sessionId.uri},
              ${this.config.auth.sessionLifetime.toString()},
              ${gameId},
              ${id},
              ${name},
              ${description},
              ${spoiler},
              ${locksWhen},
              ${optionsArray}
            )
        `),
      );
      await this.notifier.notify(async () => {
        const sql = typedSql("game_name");
        const nameResult = await client.one(
          sql`SELECT name FROM jasb.games WHERE id = ${gameId};`,
        );
        return Notifier.newBet(
          this.config.clientOrigin,
          spoiler,
          gameId,
          nameResult.name,
          id,
          name,
        );
      });
      return result;
    });
  }

  toEditOptionRow({
    id,
    version,
    name,
    image,
    order,
  }: {
    id: string;
    version?: number;
    name?: string;
    image?: string | null;
    order?: number;
  }): Slonik.ValueExpression {
    return sqlFragment`
      ROW(
        ${id}, 
        ${version ?? null}, 
        ${name ?? null}, 
        ${image ?? null}, 
        ${image === null}, 
        ${order ?? null}
      )::EditOption
    `;
  }

  async editBet(
    editor: string,
    sessionId: SecretToken,
    gameId: string,
    id: string,
    old_version: number,
    name?: string,
    description?: string,
    spoiler?: boolean,
    locksWhen?: string,
    removeOptions?: string[],
    editOptions?: {
      id: string;
      version: number;
      name?: string;
      image?: string | null;
      order?: number;
    }[],
    addOptions?: {
      id: string;
      name: string;
      image: string | null;
      order: number;
    }[],
  ): Promise<(Bets.Bet & Bets.WithOptions & Bets.Author) | undefined> {
    const editArray =
      editOptions !== undefined
        ? sqlFragment`ARRAY[${Slonik.sql.join(
            editOptions.map(this.toEditOptionRow),
            sqlFragment`, `,
          )}]`
        : null;
    const addArray =
      addOptions !== undefined
        ? sqlFragment`ARRAY[${Slonik.sql.join(
            addOptions.map(this.toEditOptionRow),
            sqlFragment`, `,
          )}]`
        : null;
    return await this.inTransaction(async (client) => {
      return (
        (await client.maybeOne(
          this.betWithOptionsAndAuthorFromBets(sqlFragment`
          SELECT
            *
          FROM
            jasb.edit_bet(
              ${editor},
              ${sessionId.uri},
              ${this.config.auth.sessionLifetime.toString()},
              ${old_version},
              ${gameId},
              ${id},
              ${name ?? null},
              ${description ?? null},
              ${spoiler ?? null},
              ${locksWhen ?? null},
              ${
                removeOptions !== undefined
                  ? Slonik.sql.array(removeOptions, "text")
                  : null
              },
              ${editArray},
              ${addArray}
            )
        `),
        )) ?? undefined
      );
    });
  }

  async setBetLocked(
    editor: string,
    sessionId: SecretToken,
    gameId: string,
    id: string,
    old_version: number,
    locked: boolean,
  ): Promise<(Bets.Bet & Bets.WithOptions & Bets.Author) | undefined> {
    return await this.withClient(async (client) => {
      return (
        (await client.maybeOne(
          this.betWithOptionsAndAuthorFromBets(sqlFragment`
          SELECT
            *
          FROM
            jasb.set_bet_locked(
              ${editor},
              ${sessionId.uri},
              ${this.config.auth.sessionLifetime.toString()},
              ${old_version},
              ${gameId},
              ${id},
              ${locked}
            )
        `),
        )) ?? undefined
      );
    });
  }

  async completeBet(
    userId: string,
    sessionId: SecretToken,
    gameId: string,
    betId: string,
    old_version: number,
    winners: string[],
  ): Promise<(Bets.Bet & Bets.WithOptions & Bets.Author) | undefined> {
    return await this.inTransaction(async (client) => {
      const result = await client.maybeOne(
        this.betWithOptionsAndAuthorFromBets(sqlFragment`
          SELECT
            *
          FROM
            jasb.complete_bet(
              ${userId},
              ${sessionId.uri},
              ${this.config.auth.sessionLifetime.toString()},
              ${old_version},
              ${gameId},
              ${betId},
              ${Slonik.sql.array(winners, "text")}
            )
        `),
      );
      await this.notifier.notify(async () => {
        const sql = typedSql("bet_complete");
        const row = await client.one(
          sql`
            SELECT 
              games.name AS game_name, 
              bets.name AS bet_name,
              bets.spoiler,
              bet_stats.winning_stakes,
              bet_stats.total_staked,
              TO_JSONB(COALESCE(bet_stats.top_winners, '{}')) AS top_winners,
              bet_stats.biggest_payout
            FROM 
              jasb.games INNER JOIN 
              jasb.bets ON games.id = bets.game INNER JOIN 
              jasb.bet_stats ON games.id = bet_stats.game AND bets.id = bet_stats.id
            WHERE 
              games.id = ${gameId} AND 
              bets.id = ${betId}
          `,
        );
        return Notifier.betComplete(
          this.config.clientOrigin,
          row.spoiler,
          gameId,
          row.game_name,
          betId,
          row.bet_name,
          winners,
          row.winning_stakes,
          row.total_staked,
          row.top_winners.map((u) => u.id),
          row.biggest_payout,
        );
      });
      return result ?? undefined;
    });
  }

  async revertCompleteBet(
    userId: string,
    sessionId: SecretToken,
    gameId: string,
    betId: string,
    old_version: number,
  ): Promise<(Bets.Bet & Bets.WithOptions & Bets.Author) | undefined> {
    return await this.inTransaction(async (client) => {
      return (
        (await client.maybeOne(
          this.betWithOptionsAndAuthorFromBets(sqlFragment`
          SELECT
            *
          FROM
            jasb.revert_complete_bet(
              ${userId},
              ${sessionId.uri},
              ${this.config.auth.sessionLifetime.toString()},
              ${old_version},
              ${gameId},
              ${betId}
            )
        `),
        )) ?? undefined
      );
    });
  }

  async cancelBet(
    userId: string,
    sessionId: SecretToken,
    gameId: string,
    betId: string,
    old_version: number,
    reason: string,
  ): Promise<(Bets.Bet & Bets.WithOptions & Bets.Author) | undefined> {
    return await this.inTransaction(async (client) => {
      return (
        (await client.maybeOne(
          this.betWithOptionsAndAuthorFromBets(sqlFragment`
          SELECT
            *
          FROM
            jasb.cancel_bet(
              ${userId},
              ${sessionId.uri},
              ${this.config.auth.sessionLifetime.toString()},
              ${old_version},
              ${gameId},
              ${betId},
              ${reason}
            )
        `),
        )) ?? undefined
      );
    });
  }

  async revertCancelBet(
    userId: string,
    sessionId: SecretToken,
    gameId: string,
    betId: string,
    old_version: number,
  ): Promise<(Bets.Bet & Bets.WithOptions & Bets.Author) | undefined> {
    return await this.inTransaction(async (client) => {
      return (
        (await client.maybeOne(
          this.betWithOptionsAndAuthorFromBets(sqlFragment`
          SELECT
            *
          FROM
            jasb.revert_cancel_bet(
              ${userId},
              ${sessionId.uri},
              ${this.config.auth.sessionLifetime.toString()},
              ${old_version},
              ${gameId},
              ${betId}
            )
        `),
        )) ?? undefined
      );
    });
  }

  async newStake(
    userId: string,
    sessionId: SecretToken,
    gameId: string,
    betId: string,
    optionId: string,
    amount: number,
    message: string | null,
  ): Promise<number> {
    return await this.inTransaction(async (client) => {
      const sql = typedSql("new_balance");
      const row = await client.one(sql`
        SELECT
          jasb.new_stake(
            ${this.config.rules.minStake},
            ${this.config.rules.notableStake},
            ${this.config.rules.maxStakeWhileInDebt},
            ${userId},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${gameId},
            ${betId},
            ${optionId},
            ${amount},
            ${message}
          ) AS new_balance;
      `);
      if (message !== null) {
        await this.notifier.notify(async () => {
          const sql = typedSql("new_stake");
          const row = await client.one(
            sql`
              SELECT 
                games.name AS game_name, 
                bets.name AS bet_name,
                bets.spoiler,
                options.name AS option_name 
              FROM 
                jasb.games INNER JOIN 
                jasb.bets ON games.id = bets.game INNER JOIN 
                jasb.options ON games.id = options.game AND bets.id = options.bet
              WHERE 
                games.id = ${gameId} AND 
                bets.id = ${betId} AND
                options.id = ${optionId};
            `,
          );
          return Notifier.newStake(
            this.config.clientOrigin,
            row.spoiler,
            gameId,
            row.game_name,
            betId,
            row.bet_name,
            row.option_name,
            userId,
            amount,
            message,
          );
        });
      }
      return row.new_balance;
    });
  }

  async withdrawStake(
    userId: string,
    sessionId: SecretToken,
    gameId: string,
    betId: string,
    optionId: string,
  ): Promise<number> {
    return await this.inTransaction(async (client) => {
      const sql = typedSql("new_balance");
      const result = await client.one(sql`
        SELECT
          jasb.withdraw_stake(
            ${userId},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${gameId},
            ${betId},
            ${optionId}
          ) AS new_balance;
      `);
      return result.new_balance;
    });
  }

  async changeStake(
    userId: string,
    sessionId: SecretToken,
    gameId: string,
    betId: string,
    optionId: string,
    amount: number,
    message: string | null,
  ): Promise<number> {
    return await this.inTransaction(async (client) => {
      const sql = typedSql("new_balance");
      const result = await client.one(sql`
        SELECT
          jasb.change_stake(
            ${this.config.rules.minStake},
            ${this.config.rules.notableStake},
            ${this.config.rules.maxStakeWhileInDebt},
            ${userId},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${gameId},
            ${betId},
            ${optionId},
            ${amount},
            ${message}
          ) AS new_balance;
      `);
      return result.new_balance;
    });
  }

  async getNotifications(
    userId: string,
    sessionId: SecretToken,
    includeRead = false,
  ): Promise<readonly Notifications.Notification[]> {
    return await this.withClient(async (client) => {
      const sql = typedSql("notification");
      const results = await client.query(sql`
        SELECT
          id,
          happened,
          notification,
          read
        FROM
          jasb.get_notifications(
            ${userId},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${includeRead}
          );
      `);
      return results.rows;
    });
  }

  async clearNotification(
    userId: string,
    sessionId: SecretToken,
    id: string,
  ): Promise<void> {
    return await this.withClient(async (client) => {
      const sql = typedSql("boolean");
      await client.query(sql`
        SELECT
          set_read AS result
        FROM
          jasb.set_read(
            ${userId},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${id}
          );
      `);
    });
  }

  async getFeed(): Promise<readonly Feed.Item[]> {
    return await this.withClient(async (client) => {
      const sql = typedSql("feed_item");
      const results = await client.query(sql`
        SELECT item, time FROM jasb.feed ORDER BY time DESC LIMIT 100;
      `);
      return results.rows;
    });
  }

  async getBetFeed(
    gameId: string,
    betId: string,
  ): Promise<readonly Feed.Item[]> {
    return await this.withClient(async (client) => {
      const sql = typedSql("feed_item");
      const results = await client.query(sql`
        SELECT
          item, time
        FROM
          jasb.feed
        WHERE
          game = ${gameId} AND 
          bet = ${betId}
        ORDER BY time DESC
      `);
      return results.rows;
    });
  }

  async getPermissions(
    userId: string,
  ): Promise<readonly Users.PerGamePermissions[]> {
    return await this.withClient(async (client) => {
      const sql = typedSql("per_game_permission");
      const results = await client.query(sql`
        SELECT
          games.id AS game_id,
          games.name AS game_name,
          COALESCE(per_game_permissions.manage_bets, FALSE) AS manage_bets
        FROM
          jasb.games LEFT JOIN
          jasb.per_game_permissions ON "user" = ${userId} AND games.id = per_game_permissions.game;
      `);
      return results.rows;
    });
  }

  async setPermissions(
    editorId: string,
    sessionId: SecretToken,
    userId: string,
    gameId: string,
    manage_bets: boolean | undefined,
  ): Promise<void> {
    await this.withClient(async (client) => {
      const sql = typedSql("per_game_permission");
      await client.query(sql`
        SELECT
          *
        FROM
          jasb.set_permissions(
            ${editorId},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${userId},
            ${gameId},
            ${manage_bets ?? null}
          );
      `);
    });
  }

  async garbageCollect(): Promise<string[]> {
    return await this.withClient(async (client) => {
      const sql = typedSql("access_token");
      const results = await client.query(sql`
        DELETE FROM
          jasb.sessions
        WHERE
          NOW() >= (started + ${this.config.auth.sessionLifetime.toString()}::INTERVAL)
        RETURNING access_token;
      `);
      return results.rows.map((row) => row.access_token);
    });
  }

  async avatarCacheGarbageCollection(
    garbageCollectBatchSize: number,
  ): Promise<string[]> {
    return await this.withClient(async (client) => {
      const sql = typedSql("avatar_cache_url");
      const results = await client.query(sql`
        SELECT 
          cached_avatars.url
        FROM
          jasb.cached_avatars
        WHERE NOT EXISTS (
          SELECT FROM jasb.users
          WHERE cached_avatars.url = users.avatar_cache
        ) LIMIT ${garbageCollectBatchSize};
      `);
      return results.rows.map((row) => row.url);
    });
  }

  async avatarsToCache(
    cacheBatchSize: number,
  ): Promise<readonly AvatarCache.CacheDetails[]> {
    return await this.withClient(async (client) => {
      const sql = typedSql("avatar_cache_details");
      const results = await client.query(sql`
        SELECT
          users.discriminator,
          users.id,
          users.avatar
        FROM
          jasb.users
        WHERE
          users.avatar_cache IS NULL
        LIMIT ${cacheBatchSize};
      `);
      return results.rows;
    });
  }

  async updateCachedAvatars(
    added: { user: string; key: AvatarCache.Key; url: string }[],
  ): Promise<void> {
    const sql = typedSql("void");
    await this.withClient(
      async (client) =>
        await Promise.all([
          client.query(sql`
            INSERT INTO jasb.cached_avatars (url, key) 
            SELECT DISTINCT * FROM ${Slonik.sql.unnest(
              added.map(({ key, url }) => [url, JSON.stringify(key)]),
              ["text", "jsonb"],
            )}
            ON CONFLICT DO NOTHING;
          `),
          client.query(sql`
            UPDATE jasb.users 
            SET 
              avatar_cache = added.url 
            FROM (SELECT "user", url FROM ${Slonik.sql.unnest(
              added.map(({ user, url }) => [user, url]),
              ["text", "text"],
            )} AS added("user", url)) AS added 
            WHERE 
              users.id = added."user"
          `),
        ]),
    );
  }

  async deleteCachedAvatars(deleted: string[]): Promise<void> {
    const sql = typedSql("void");
    await this.withClient(
      async (client) =>
        await client.query(sql`
          DELETE FROM jasb.cached_avatars 
          WHERE url = ANY(${Slonik.sql.array(deleted, "text")});
        `),
    );
  }

  async unload(): Promise<void> {
    await this.pool.end();
  }

  private async withClient<Value>(
    operation: (client: Slonik.DatabasePoolConnection) => Promise<Value>,
  ): Promise<Value> {
    return await Store.translatingErrors(
      async () => await this.pool.connect(operation),
    );
  }

  private async inTransaction<Value>(
    operation: (client: Slonik.DatabaseTransactionConnection) => Promise<Value>,
  ): Promise<Value> {
    return await Store.translatingErrors(
      async () => await this.pool.transaction(operation),
    );
  }

  private static async translatingErrors<Value>(
    operation: () => Promise<Value>,
  ): Promise<Value> {
    try {
      return await operation();
    } catch (anyError) {
      const error = anyError as Error & {
        code?: string;
      };
      if (error?.code !== undefined) {
        switch (error.code) {
          case "UAUTH":
            throw new WebError(
              StatusCodes.UNAUTHORIZED,
              `Unauthorized: ${error.message}`,
            );
          case "NTFND":
            throw new WebError(
              StatusCodes.NOT_FOUND,
              `Not Found: ${error.message}`,
            );
          case "FRBDN":
            throw new WebError(
              StatusCodes.FORBIDDEN,
              `Forbidden: ${error.message}`,
            );
          case "BDREQ":
            throw new WebError(
              StatusCodes.BAD_REQUEST,
              `Bad Request: ${error.message}`,
            );
          case "CONFL":
            throw new WebError(
              StatusCodes.CONFLICT,
              `Conflict: ${error.message}`,
            );
          case "ISERR":
            throw new WebError(
              StatusCodes.INTERNAL_SERVER_ERROR,
              `Internal Server Error: ${error.message}`,
            );
        }
      }
      throw anyError;
    }
  }
}
