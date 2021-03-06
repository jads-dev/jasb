import * as Joda from "@js-joda/core";
import { StatusCodes } from "http-status-codes";
import { default as Pg } from "pg";
import parseInterval from "postgres-interval";
import { migrate } from "postgres-migrations";
import {
  default as Slonik,
  QueryResultRow,
  sql,
  SqlTaggedTemplate,
  TaggedTemplateLiteralInvocation,
} from "slonik";

import {
  AvatarCache,
  Bet,
  Bets,
  Feed,
  Game,
  Games,
  Notification,
  User,
  Users,
} from "../internal.js";
import { Config } from "../server/config.js";
import { WebError } from "../server/errors.js";
import { Logging } from "../server/logging.js";
import { Notifier } from "../server/notifier.js";
import { SecretToken } from "../util/secret-token.js";
import { ObjectUploader } from "./object-upload.js";

const postgresDateTimeFormatter = new Joda.DateTimeFormatterBuilder()
  .parseCaseInsensitive()
  .append(Joda.DateTimeFormatter.ISO_LOCAL_DATE)
  .appendLiteral(" ")
  .append(Joda.DateTimeFormatter.ISO_LOCAL_TIME)
  .optionalStart()
  .appendOffset("+HH", "Z")
  .optionalEnd()
  .toFormatter(Joda.ResolverStyle.STRICT);

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
  ) {
    this.logger = logger.child({
      system: "store",
      store: "postgres",
    });
    this.config = config;
    this.notifier = notifier;
    this.avatarCache = avatarCache;
    this.pool = Slonik.createPool(
      Store.connectionString(this.config.store.source),
      {
        typeParsers: [
          {
            name: "date",
            parse: Joda.LocalDate.parse,
          },
          { name: "int8", parse: (v) => Number.parseInt(v, 10) },
          {
            name: "interval",
            parse: (v) => Joda.Duration.parse(parseInterval(v).toISOString()),
          },
          {
            name: "timestamptz",
            parse: (v) =>
              Joda.ZonedDateTime.parse(v, postgresDateTimeFormatter),
          },
        ],
      },
    );
  }

  public static async load(
    logger: Logging.Logger,
    config: Config.Server,
    notifier: Notifier,
    avatarCache: ObjectUploader | undefined,
  ): Promise<Store> {
    const store = new Store(logger, config, notifier, avatarCache);
    await store.migrate(store.logger);
    return store;
  }

  private async migrate(logger: Logging.Logger): Promise<void> {
    const client = new Pg.Client(
      Store.connectionString(this.config.store.source),
    );
    await client.connect();
    const migrationLogger = logger.child({
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
      await client.query(sql`
        SELECT
          *
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
  ): Promise<(User & Users.Permissions & Users.BetStats) | undefined> {
    return await this.withClient(async (client) => {
      if (sessionId !== undefined) {
        await client.query(sql`
          SELECT
            *
          FROM
            jasb.validate_session(
              ${id},
              ${sessionId.uri},
              ${this.config.auth.sessionLifetime.toString()}
            );
        `);
      }
      const results = await client.query(sql`
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
      return results.rowCount > 0
        ? (results.rows[0] as unknown as User &
            Users.Permissions &
            Users.BetStats)
        : undefined;
    });
  }

  async getLeaderboard(): Promise<
    (User & Users.BetStats & Users.Leaderboard)[]
  > {
    return await this.withClient(async (client) => {
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
      return results.rows as unknown as (User &
        Users.BetStats &
        Users.Leaderboard)[];
    });
  }

  async bankruptcyStats(userId: string): Promise<Users.BankruptcyStats> {
    return await this.withClient(async (client) => {
      const result = await client.query(sql`
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
      return result.rows[0] as unknown as Users.BankruptcyStats;
    });
  }

  async bankrupt(userId: string, sessionId: SecretToken): Promise<User> {
    return await this.inTransaction(async (client) => {
      const result = await client.query(sql`
        SELECT
          id,
          name,
          discriminator,
          avatar,
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
      return result.rows[0] as unknown as User;
    });
  }

  async login(
    userId: string,
    name: string,
    discriminator: string,
    avatar: string | null,
    accessToken: string,
    refreshToken: string,
    discordExpiresIn: Joda.Duration,
  ): Promise<{
    user: User & Users.Permissions & Users.BetStats & Users.LoginDetail;
    notifications: Notification[];
  }> {
    const sessionId = await SecretToken.secureRandom(
      this.config.auth.sessionIdSize,
    );
    return await this.inTransaction(async (client) => {
      await client.query(sql`
        SELECT * FROM jasb.login(
          ${userId},
          ${sessionId.uri},
          ${name},
          ${discriminator},
          ${avatar},
          ${accessToken},
          ${refreshToken},
          ${discordExpiresIn.toString()},
          ${this.config.rules.initialBalance}
        );
      `);
      const [loginResults, notificationResults] = await Promise.all([
        client.query(sql`
          SELECT
            users.*,
            sessions.session,
            sessions.started,
            (users.staked + users.balance) AS net_worth,
            COALESCE(ARRAY_AGG(permissions.game) FILTER ( WHERE permissions.game IS NOT NULL ), '{}') AS moderator_for
          FROM
            sessions LEFT JOIN
            jasb.users_with_stakes AS users ON users.id = sessions."user" LEFT JOIN
            jasb.permissions ON sessions."user" = permissions."user" AND manage_bets = TRUE
          WHERE
            sessions."user" = ${userId}
          GROUP BY (
            users.id,
            users.name,
            users.discriminator,
            users.avatar,
            users.avatar_cache,
            users.created,
            users.admin,
            users.balance,
            users.staked,
            sessions.session,
            sessions.started
          );
        `),
        client.query(sql`
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
        `),
      ]);
      const user = loginResults.rows[0] as unknown as User &
        Users.Permissions &
        Users.BetStats &
        Users.LoginDetail;
      return {
        user,
        notifications: notificationResults.rows as unknown as Notification[],
      };
    });
  }

  async logout(
    userId: string,
    session: SecretToken,
  ): Promise<string | undefined> {
    return await this.withClient(async (client) => {
      const results = await client.query(sql`
        DELETE FROM
          jasb.sessions
        WHERE
          "user" = ${userId} AND 
          session = ${session.uri}
        RETURNING access_token;
      `);
      if (results.rowCount > 0) {
        return results.rows[0]?.access_token as string;
      } else {
        return undefined;
      }
    });
  }

  async getTile(
    gameId: string,
    betId: string | null,
  ): Promise<{ game_name: string; bet_name: string | null } | undefined> {
    return await this.withClient(async (client) => {
      const results = await client.query(sql`
        SELECT
          games.name AS game_name,
          bets.name AS bet_name
        FROM
          jasb.games LEFT JOIN 
          jasb.bets ON games.id = bets.game
        WHERE
          games.id = ${gameId} AND 
          (bets.id = ${betId} OR bets.id IS NULL)
        LIMIT 1;
      `);
      return results.rowCount > 0
        ? (results.rows[0] as { game_name: string; bet_name: string | null })
        : undefined;
    });
  }

  async getGame(
    id: string,
  ): Promise<
    (Game & Games.BetStats & Games.StakeStats & Games.Mods) | undefined
  > {
    return await this.withClient(async (client) => {
      const results = await client.query(sql`
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
      `);
      return results.rowCount > 0
        ? (results.rows[0] as unknown as Game &
            Games.BetStats &
            Games.StakeStats &
            Games.Mods)
        : undefined;
    });
  }

  getSort(
    subset: Games.Progress,
  ): TaggedTemplateLiteralInvocation<QueryResultRow> {
    switch (subset) {
      case "Future":
        return sql`games."order" ASC NULLS LAST`;
      case "Current":
        return sql`games.started ASC`;
      case "Finished":
        return sql`games.finished DESC`;
    }
  }

  async getGames(subset: Games.Progress): Promise<(Game & Games.BetStats)[]> {
    return await this.withClient(async (client) => {
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

      return results.rows as unknown as (Game & Games.BetStats)[];
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
  ): Promise<Game> {
    return await this.withClient(async (client) => {
      const result = await client.query(sql`
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
      return result.rows[0] as unknown as Game;
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
  ): Promise<Game & Games.BetStats> {
    return await this.withClient(async (client) => {
      const results = await client.query(sql`
        SELECT
          *
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
          );
      `);
      return results.rows[0] as unknown as Game & Games.BetStats;
    });
  }

  async getBets(gameId: string): Promise<(Bet & Bets.Options)[]> {
    return await this.withClient(async (client) => {
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
      return results.rows as unknown as (Bet & Bets.Options)[];
    });
  }

  async getBetsLockStatus(gameId: string): Promise<Bets.LockStatus[]> {
    return await this.withClient(async (client) => {
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
      return results.rows as unknown as Bets.LockStatus[];
    });
  }

  async getUserBets(userId: string): Promise<(Game & Games.EmbeddedBets)[]> {
    return await this.withClient(async (client) => {
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
      return results.rows as unknown as (Game & Games.EmbeddedBets)[];
    });
  }

  betWithOptionsAndAuthorFromBets<T>(
    betsSubquery: Slonik.TaggedTemplateLiteralInvocation<T>,
  ): Slonik.TaggedTemplateLiteralInvocation<T> {
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
  ): Promise<(Bet & Bets.Options & Bets.Author) | undefined> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        this.betWithOptionsAndAuthorFromBets(sql`
          SELECT * FROM jasb.bets WHERE bets.game = ${gameId} AND bets.id = ${betId}
        `),
      );
      return results.rowCount > 0
        ? (results.rows[0] as unknown as Bet & Bets.Options & Bets.Author)
        : undefined;
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
    return sql`ROW(${id}, ${name ?? null}, ${image ?? null})::AddOption`;
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
  ): Promise<Bet & Bets.Options & Bets.Author> {
    const optionsArray =
      options !== undefined
        ? sql`ARRAY[${sql.join(options.map(this.toAddOptionRow), sql`, `)}]`
        : null;
    return await this.inTransaction(async (client) => {
      const results = await client.query(
        this.betWithOptionsAndAuthorFromBets(sql`
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
        const nameResult = await client.query(
          sql`SELECT name FROM jasb.games WHERE id = ${gameId};`,
        );
        return Notifier.newBet(
          this.config.clientOrigin,
          spoiler,
          gameId,
          nameResult.rows[0]?.name as string,
          id,
          name,
        );
      });
      return results.rows[0] as unknown as Bet & Bets.Options & Bets.Author;
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
    return sql`
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
  ): Promise<(Bet & Bets.Options & Bets.Author) | undefined> {
    const editArray =
      editOptions !== undefined
        ? sql`ARRAY[${sql.join(
            editOptions.map(this.toEditOptionRow),
            sql`, `,
          )}]`
        : null;
    const addArray =
      addOptions !== undefined
        ? sql`ARRAY[${sql.join(addOptions.map(this.toEditOptionRow), sql`, `)}]`
        : null;
    return await this.inTransaction(async (client) => {
      const results = await client.query(
        this.betWithOptionsAndAuthorFromBets(sql`
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
                  ? sql.array(removeOptions, "text")
                  : null
              },
              ${editArray},
              ${addArray}
            )
        `),
      );
      return results.rowCount > 0
        ? (results.rows[0] as unknown as Bet & Bets.Options & Bets.Author)
        : undefined;
    });
  }

  async setBetLocked(
    editor: string,
    sessionId: SecretToken,
    gameId: string,
    id: string,
    old_version: number,
    locked: boolean,
  ): Promise<(Bet & Bets.Options & Bets.Author) | undefined> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        this.betWithOptionsAndAuthorFromBets(sql`
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
      );
      return results.rowCount > 0
        ? (results.rows[0] as unknown as Bet & Bets.Options & Bets.Author)
        : undefined;
    });
  }

  async completeBet(
    userId: string,
    sessionId: SecretToken,
    gameId: string,
    betId: string,
    old_version: number,
    winners: string[],
  ): Promise<(Bet & Bets.Options & Bets.Author) | undefined> {
    return await this.inTransaction(async (client) => {
      const results = await client.query(
        this.betWithOptionsAndAuthorFromBets(sql`
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
              ${sql.array(winners, "text")}
            )
        `),
      );
      await this.notifier.notify(async () => {
        const detailsResult = await client.query(
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
        const row = detailsResult.rows[0];
        if (row === undefined) {
          throw new Error("Unexpected empty result.");
        }
        return Notifier.betComplete(
          this.config.clientOrigin,
          row.spoiler as boolean,
          gameId,
          row.game_name as string,
          betId,
          row.bet_name as string,
          winners,
          row.winning_stakes as number,
          row.total_staked as number,
          (row.top_winners as unknown as User[]).map((u) => u.id),
          row.biggest_payout as number,
        );
      });
      return results.rowCount > 0
        ? (results.rows[0] as unknown as Bet & Bets.Options & Bets.Author)
        : undefined;
    });
  }

  async revertCompleteBet(
    userId: string,
    sessionId: SecretToken,
    gameId: string,
    betId: string,
    old_version: number,
  ): Promise<(Bet & Bets.Options & Bets.Author) | undefined> {
    return await this.inTransaction(async (client) => {
      const results = await client.query(
        this.betWithOptionsAndAuthorFromBets(sql`
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
      );
      return results.rowCount > 0
        ? (results.rows[0] as unknown as Bet & Bets.Options & Bets.Author)
        : undefined;
    });
  }

  async cancelBet(
    userId: string,
    sessionId: SecretToken,
    gameId: string,
    betId: string,
    old_version: number,
    reason: string,
  ): Promise<(Bet & Bets.Options & Bets.Author) | undefined> {
    return await this.inTransaction(async (client) => {
      const results = await client.query(
        this.betWithOptionsAndAuthorFromBets(sql`
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
      );
      return results.rowCount > 0
        ? (results.rows[0] as unknown as Bet & Bets.Options & Bets.Author)
        : undefined;
    });
  }

  async revertCancelBet(
    userId: string,
    sessionId: SecretToken,
    gameId: string,
    betId: string,
    old_version: number,
  ): Promise<(Bet & Bets.Options & Bets.Author) | undefined> {
    return await this.inTransaction(async (client) => {
      const results = await client.query(
        this.betWithOptionsAndAuthorFromBets(sql`
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
      );
      return results.rowCount > 0
        ? (results.rows[0] as unknown as Bet & Bets.Options & Bets.Author)
        : undefined;
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
      const result = await client.query(sql`
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
      const row = result.rows[0];
      if (message !== null) {
        await this.notifier.notify(async () => {
          const detailsResult = await client.query(
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
          const row = detailsResult.rows[0];
          if (row === undefined) {
            throw new Error("Unexpected empty result.");
          }
          return Notifier.newStake(
            this.config.clientOrigin,
            row.spoiler as boolean,
            gameId,
            row.game_name as string,
            betId,
            row.bet_name as string,
            row.option_name as string,
            userId as string,
            amount as number,
            message as string,
          );
        });
      }
      return row?.new_balance as number;
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
      const result = await client.query(sql`
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
      return result.rows[0]?.new_balance as number;
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
      const result = await client.query(sql`
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
      return result.rows[0]?.new_balance as number;
    });
  }

  async getNotifications(
    userId: string,
    sessionId: SecretToken,
    includeRead = false,
  ): Promise<Notification[]> {
    return await this.withClient(async (client) => {
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
      return results.rows as unknown as Notification[];
    });
  }

  async clearNotification(
    userId: string,
    sessionId: SecretToken,
    id: string,
  ): Promise<void> {
    return await this.withClient(async (client) => {
      await client.query(sql`
        SELECT
          *
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

  async getFeed(): Promise<Feed.Item[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(sql`
        SELECT item FROM jasb.feed ORDER BY time DESC LIMIT 100;
      `);
      return results.rows as unknown as Feed.Item[];
    });
  }

  async getBetFeed(gameId: string, betId: string): Promise<Feed.Item[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(sql`
        SELECT
          item
        FROM
          jasb.feed
        WHERE
          game = ${gameId} AND 
          bet = ${betId}
        ORDER BY time DESC
      `);
      return results.rows as unknown as Feed.Item[];
    });
  }

  async getPermissions(userId: string): Promise<Users.PerGamePermissions[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(sql`
        SELECT
          games.id AS game_id,
          games.name AS game_name,
          COALESCE(per_game_permissions.manage_bets, FALSE) AS manage_bets
        FROM
          jasb.games LEFT JOIN
          jasb.per_game_permissions ON "user" = ${userId} AND games.id = per_game_permissions.game;
      `);
      return results.rows as unknown as Users.PerGamePermissions[];
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
      const results = await client.query(sql`
        DELETE FROM
          jasb.sessions
        WHERE
          NOW() >= (started + ${this.config.auth.sessionLifetime.toString()}::INTERVAL)
        RETURNING access_token;
      `);
      return results.rows.map((row: any) => row.access_token as string);
    });
  }

  async avatarCacheGarbageCollection(
    garbageCollectBatchSize: number,
  ): Promise<string[]> {
    return await this.withClient(async (client) => {
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
      return results.rows.map((row: any) => row.url as string);
    });
  }

  async avatarsToCache(
    cacheBatchSize: number,
  ): Promise<AvatarCache.CacheDetails[]> {
    return await this.withClient(async (client) => {
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
      return results.rows as unknown as AvatarCache.CacheDetails[];
    });
  }

  async updateCachedAvatars(
    added: { user: string; key: AvatarCache.Key; url: string }[],
  ): Promise<void> {
    await this.withClient(
      async (client) =>
        await Promise.all([
          client.query(sql`
            INSERT INTO jasb.cached_avatars (url, key) 
            SELECT DISTINCT * FROM ${sql.unnest(
              added.map(({ key, url }) => [url, JSON.stringify(key)]),
              ["text", "jsonb"],
            )}
            ON CONFLICT DO NOTHING;
          `),
          client.query(sql`
            UPDATE jasb.users 
            SET 
              avatar_cache = added.url 
            FROM (SELECT "user", url FROM ${sql.unnest(
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
    await this.withClient(
      async (client) =>
        await client.query(sql`
        DELETE FROM jasb.cached_avatars 
        WHERE url = ANY(${sql.array(deleted, "text")});
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
