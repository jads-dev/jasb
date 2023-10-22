import type * as Joda from "@js-joda/core";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";
import { default as Slonik } from "slonik";

import { Bets, Feed, Gacha, Games, Notifications, Users } from "../internal.js";
import type { Public } from "../public.js";
import type { DiscordToken } from "../server/auth.js";
import { Credentials } from "../server/auth/credentials.js";
import { Background } from "../server/background.js";
import { sendExternalNotification } from "../server/background/send-external-notification.js";
import type { Config } from "../server/config.js";
import { WebError } from "../server/errors.js";
import { Logging } from "../server/logging.js";
import type { Server } from "../server/model.js";
import { Iterables } from "../util/iterables.js";
import { SecretToken } from "../util/secret-token.js";
import type { Objects } from "./objects.js";
import { Queries } from "./store/queries.js";

const createResultParserInterceptor = (): Slonik.Interceptor => ({
  transformRow: ({ resultParser }, actualQuery, row) => {
    if (resultParser) {
      const validationResult = resultParser.safeParse(row);
      if (validationResult.success) {
        return validationResult.data as Slonik.QueryResultRow;
      } else {
        throw new Slonik.SchemaValidationError(
          actualQuery,
          row,
          validationResult.error.issues,
        );
      }
    } else {
      return row;
    }
  },
});

const sqlFragment = Slonik.sql.fragment;

export class Store {
  readonly #config: Config.Server;
  readonly #pool: Slonik.DatabasePool;

  public static connectionString({
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

  private constructor(config: Config.Server, pool: Slonik.DatabasePool) {
    this.#config = config;
    this.#pool = pool;
  }

  public static async load(config: Config.Server): Promise<Store> {
    return new Store(
      config,
      await Slonik.createPool(Store.connectionString(config.store.source), {
        typeParsers: [
          { name: "int8", parse: (v) => Number.parseInt(v, 10) },
          { name: "timestamptz", parse: (v) => v },
          { name: "bytea", parse: (v) => v },
        ],
        interceptors: [createResultParserInterceptor()],
      }),
    );
  }

  anyOf(ids: readonly { id: number }[]) {
    return sqlFragment`
      ANY(${Slonik.sql.array(
        ids.map(({ id }) => id),
        "int4",
      )})
    `;
  }

  sqlCredential(credential: Credentials.Credential) {
    return Slonik.sql.jsonb(Credentials.Credential.encode(credential));
  }

  async validateUpload(credential: Credentials.Identifying): Promise<number> {
    const result = await this.withClient(
      async (client) =>
        // This will throw if not authorized.
        await client.one(
          Queries.userId(sqlFragment`
            jasb.validate_upload(
              ${this.sqlCredential(credential)},
              ${this.#config.auth.sessions.lifetime.toString()}
            )
          `),
        ),
    );
    return result.user_id;
  }

  async validateCredential(
    credential: Credentials.Identifying,
  ): Promise<number> {
    const result = await this.withClient(
      async (client) =>
        await client.one(
          Queries.userId(sqlFragment`
            jasb.validate_credentials(
              ${this.sqlCredential(credential)},
              ${this.#config.auth.sessions.lifetime.toString()}
            )
          `),
        ),
    );
    return result.user_id;
  }

  async getUser(userSlug: Public.Users.Slug): Promise<Users.User | undefined> {
    return await this.withClient(async (client) => {
      const result = await client.maybeOne(
        Queries.user(sqlFragment`
          SELECT users.* FROM users WHERE users.slug = ${userSlug}
        `),
      );
      return result ?? undefined;
    });
  }

  async searchUsers(query: string): Promise<readonly Users.Summary[]> {
    const result = await this.withClient(
      async (client) =>
        await client.query(
          Queries.userSummary(
            sqlFragment`
              SELECT
                users.*,
                strict_word_similarity(${query}, users.search) AS rank
              FROM jasb.users
              WHERE ${query} <<% users.search
              ORDER BY rank
              LIMIT 10
            `,
            sqlFragment`ORDER BY users.rank DESC`,
          ),
        ),
    );
    return result.rows;
  }

  async getNetWorthLeaderboard(): Promise<readonly Users.Leaderboard[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.leaderboard(sqlFragment`
          SELECT leaderboard.* 
          FROM jasb.leaderboard
          WHERE net_worth > ${this.#config.rules.initialBalance}
        `),
      );
      return results.rows;
    });
  }

  async getDebtLeaderboard(): Promise<readonly Users.Leaderboard[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.leaderboard(sqlFragment`
          SELECT debt_leaderboard.* 
          FROM jasb.debt_leaderboard
          WHERE balance < 0
        `),
      );
      return results.rows;
    });
  }

  async bankruptcyStats(
    userSlug: Public.Users.Slug,
  ): Promise<Users.BankruptcyStats> {
    return await this.withClient(async (client) => {
      return await client.one(
        Queries.bankruptcyStats(
          this.#config.rules.initialBalance,
          sqlFragment`
            SELECT * from jasb.users WHERE users.slug = ${userSlug}
          `,
        ),
      );
    });
  }

  async bankrupt(credential: Credentials.Identifying): Promise<Users.User> {
    return await this.inTransaction(async (client) => {
      return await client.one(
        Queries.user(sqlFragment`
          SELECT * FROM jasb.bankrupt(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${this.#config.rules.initialBalance}
        )`),
      );
    });
  }

  async login(
    discordId: string,
    username: string,
    display_name: string | null,
    discriminator: string | null,
    avatar: string | null,
    accessToken: string,
    refreshToken: string,
    discordExpiresAt: Joda.Instant,
  ): Promise<{
    user: Users.User & Users.LoginDetail;
    notifications: readonly Notifications.Notification[];
  }> {
    const sessionId = await SecretToken.secureRandom(
      this.#config.auth.sessions.idSize,
    );
    return await this.inTransaction(async (client) => {
      const session = await (async () => {
        return await client.one(
          Queries.session(sqlFragment`
            SELECT * FROM jasb.login(
              ${discordId},
              ${sessionId.uri},
              ${username},
              ${display_name},
              ${discriminator},
              ${avatar},
              ${accessToken},
              ${refreshToken},
              ${discordExpiresAt.toString()},
              ${this.#config.rules.initialBalance}
            )
          `),
        );
      })();
      const login = async () => {
        const user = await client.one(
          Queries.user(sqlFragment`
            SELECT users.* FROM users WHERE users.id = ${session.user}
          `),
        );
        return { ...user, ...session };
      };
      const notification = async () => {
        return await client.query(
          Queries.notification(sqlFragment`
            SELECT notifications.* FROM jasb.notifications
            WHERE "for" = ${session.user} AND read IS NOT TRUE
          `),
        );
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
    userSlug: Public.Users.Slug,
    session: SecretToken,
  ): Promise<string | undefined> {
    return await this.inTransaction(async (client) => {
      const result = await client.maybeOne(
        Queries.accessToken(sqlFragment`
          DELETE FROM
            jasb.sessions
          USING
            jasb.users
          WHERE
            users.slug = ${userSlug} AND
            sessions."user" = users.id AND 
            session = ${session.uri}
          RETURNING sessions.*
        `),
      );
      return result?.access_token;
    });
  }

  async findSessionsToRefresh(
    nextSearch: Joda.Duration,
    buffer: Joda.Duration,
  ): Promise<readonly Users.DiscordRefreshToken[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.refreshToken(sqlFragment`
          SELECT sessions.* 
          FROM jasb.sessions 
          WHERE discord_expires < (NOW() + ${nextSearch.toString()}::interval - ${buffer.toString()}::interval)
        `),
      );
      return results.rows;
    });
  }

  async updateRefreshedSessions(
    sessions: readonly {
      id: number;
      newToken: DiscordToken;
    }[],
  ): Promise<number> {
    return await this.withClient(async (client) => {
      const unnest = Slonik.sql.unnest(
        sessions.map(({ id, newToken }) => [
          id,
          newToken.accessToken,
          newToken.refreshToken,
          newToken.expiresAt.toString(),
        ]),
        ["int4", "text", "text", "timestamptz"],
      );
      const results = await client.query(
        Queries.refreshToken(sqlFragment`
          UPDATE sessions
          SET 
            access_token = updates.access_token,
            refresh_token = updates.refresh_token,
            discord_expires = updates.expires_at
          FROM ${unnest} AS updates(id, access_token, refresh_token, expires_at)
          WHERE sessions.id = updates.id
          RETURNING sessions.id, sessions.refresh_token
        `),
      );
      return results.rowCount;
    });
  }

  async deleteExpiredSessions(sessions: readonly number[]): Promise<number> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.ids(sqlFragment`
          DELETE FROM sessions
          WHERE id = ANY(${Slonik.sql.array(sessions, "int4")})
          RETURNING id
        `),
      );
      return results.rowCount;
    });
  }

  async getGame(
    gameSlug: Public.Games.Slug,
  ): Promise<(Games.Game & Games.BetStats) | undefined> {
    return await this.withClient(async (client) => {
      const result = await client.maybeOne(
        Queries.gameWithBetStats(sqlFragment`
          SELECT games.* FROM jasb.games WHERE games.slug = ${gameSlug}
        `),
      );
      return result ?? undefined;
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
      const results = await client.query(
        Queries.gameWithBetStats(
          sqlFragment`
            SELECT games.* FROM jasb.games WHERE games.progress = ${subset}
          `,
          sqlFragment`ORDER BY ${this.getSort(subset)}, games.created ASC`,
        ),
      );
      return results.rows;
    });
  }

  async addGame(
    credential: Credentials.Identifying,
    gameSlug: Public.Games.Slug,
    name: string,
    cover: string,
    started: Joda.LocalDate | null,
    finished: Joda.LocalDate | null,
    order: number | null,
  ): Promise<number> {
    const result = await this.inTransaction(
      async (client) =>
        await client.one(
          Queries.id(sqlFragment`
            SELECT * FROM jasb.add_game(
              ${this.sqlCredential(credential)},
              ${this.#config.auth.sessions.lifetime.toString()},
              ${gameSlug},
              ${name},
              ${cover},
              ${started?.toString() ?? null},
              ${finished?.toString() ?? null},
              ${order}
            ) AS games
          `),
        ),
    );
    return result.id;
  }

  async searchGames(query: string): Promise<readonly Games.Summary[]> {
    const result = await this.withClient(
      async (client) =>
        await client.query(
          Queries.gameSummary(
            sqlFragment`
              SELECT games.*
              FROM jasb.games
              WHERE ${query} <<% games.search
              ORDER BY strict_word_similarity(${query}, games.search) DESC
              LIMIT 10
            `,
          ),
        ),
    );
    return result.rows;
  }

  async editGame(
    credential: Credentials.Identifying,
    version: number,
    gameSlug: Public.Games.Slug,
    name?: string,
    cover?: string,
    started?: Joda.LocalDate | null,
    finished?: Joda.LocalDate | null,
    order?: number | null,
  ): Promise<number> {
    const result = await this.inTransaction(
      async (client) =>
        await client.one(
          Queries.id(sqlFragment`
            SELECT * FROM jasb.edit_game(
              ${this.sqlCredential(credential)},
              ${this.#config.auth.sessions.lifetime.toString()},
              ${gameSlug},
              ${version},
              ${name ?? null},
              ${cover ?? null},
              ${started?.toString() ?? null},
              ${started === null},
              ${finished?.toString() ?? null},
              ${finished === null},
              ${order ?? null},
              ${order === null}
            )
          `),
        ),
    );
    return result.id;
  }

  async getLockMoments(gameSlug: string): Promise<readonly Bets.LockMoment[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.lockMoment(sqlFragment`
          SELECT lock_moments.* 
          FROM 
            jasb.lock_moments INNER JOIN 
            jasb.games ON 
              lock_moments.game = games.id AND 
              games.slug = ${gameSlug}
        `),
      );
      return results.rows;
    });
  }

  async editLockMoments(
    credential: Credentials.Identifying,
    gameSlug: Public.Games.Slug,
    remove?: readonly { id: Public.Editor.LockMoments.Slug; version: number }[],
    edit?: readonly {
      id: Public.Editor.LockMoments.Slug;
      version: number;
      name?: string;
      order?: number;
    }[],
    add?: readonly {
      id: Public.Editor.LockMoments.Slug;
      name: string;
      order: number;
    }[],
  ): Promise<readonly Bets.LockMoment[]> {
    return await this.inTransaction(async (client) => {
      const removeUnnest = Slonik.sql.unnest(
        (remove ?? []).map(({ id, version }) => [id, version]),
        ["text", "int4"],
      );
      const editUnnest = Slonik.sql.unnest(
        (edit ?? []).map(({ id, version, name, order }) => [
          id,
          version,
          name ?? null,
          order ?? null,
        ]),
        ["text", "int4", "text", "int4"],
      );
      const addUnnest = Slonik.sql.unnest(
        (add ?? []).map(({ id, name, order }) => [id, name, order]),
        ["text", "text", "int4"],
      );
      const result = await client.query(
        Queries.lockMoment(sqlFragment`
          SELECT * FROM jasb.edit_lock_moments(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${gameSlug},
            (SELECT array_agg(
              row(slug, version)::RemoveLockMoment
            ) FROM ${removeUnnest} AS removes(slug, version)),
            (SELECT array_agg(
              row(slug, version, name, "order")::EditLockMoment
            ) FROM ${editUnnest} AS edits(slug, version, name, "order")),
            (SELECT array_agg(
              row(slug, name, "order")::AddLockMoment
            ) FROM ${addUnnest} AS edits(slug, name, "order"))
          )
        `),
      );
      return result.rows;
    });
  }

  async getBets(
    gameSlug: Public.Games.Slug,
  ): Promise<readonly (Bets.Bet & Bets.WithOptions)[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.betWithOptions(sqlFragment`
          SELECT bets.* 
          FROM jasb.bets INNER JOIN jasb.games ON bets.game = games.id
          WHERE games.slug = ${gameSlug}
        `),
      );
      return results.rows;
    });
  }

  async getBetsLockStatus(
    gameSlug: Public.Games.Slug,
  ): Promise<readonly Bets.LockStatus[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.lockStatus(sqlFragment`
          SELECT bets.* 
          FROM jasb.bets INNER JOIN jasb.games ON bets.game = games.id
          WHERE games.slug = ${gameSlug}
        `),
      );
      return results.rows;
    });
  }

  async getUserBets(
    userSlug: Public.Users.Slug,
  ): Promise<readonly (Games.Game & Games.WithBets)[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.gameWithBets(sqlFragment`
          SELECT 
            bets.*,
            max(stakes.made_at) AS game_order
          FROM
            jasb.users INNER JOIN 
            jasb.stakes ON users.id = stakes.owner INNER JOIN
            jasb.options ON stakes.option = options.id INNER JOIN
            jasb.bets ON options.bet = bets.id
          WHERE users.slug = ${userSlug}
          GROUP BY bets.id
          LIMIT 100
        `),
      );
      return results.rows;
    });
  }

  async getBet(
    gameSlug: Public.Games.Slug,
    betSlug: Public.Bets.Slug,
  ): Promise<Bets.Editable | undefined> {
    return await this.withClient(async (client) => {
      const result = await client.maybeOne(
        Queries.editableBet(sqlFragment`
          SELECT bets.* 
          FROM 
            jasb.bets INNER JOIN 
            jasb.games ON bets.game = games.id AND games.slug = ${gameSlug} 
          WHERE bets.slug = ${betSlug}
        `),
      );
      return result ?? undefined;
    });
  }

  async addBet(
    server: Server.State,
    logger: Logging.Logger,
    credential: Credentials.Identifying,
    gameSlug: Public.Games.Slug,
    betSlug: Public.Bets.Slug,
    betName: string,
    description: string,
    spoiler: boolean,
    lockMomentSlug: string,
    options: {
      id: string;
      name: string;
      image: string | null;
    }[],
  ): Promise<Bets.Editable> {
    const addUnnest = Slonik.sql.unnest(
      options.map(({ id, name, image }) => [id, name, image ?? null]),
      ["text", "text", "text"],
    );
    return await this.inTransaction(async (client) => {
      const result = await client.one(
        Queries.editableBet(sqlFragment`
          SELECT *
          FROM jasb.add_bet(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${gameSlug},
            ${betSlug},
            ${betName},
            ${description},
            ${spoiler},
            ${lockMomentSlug},
            (
              SELECT array_agg(
                row(slug, name, image, 0)::AddOption
              ) FROM ${addUnnest} AS adds(slug, name, image)
            )
          )
        `),
      );
      Background.runTask(
        server,
        logger,
        sendExternalNotification(async (): Promise<Feed.NewBet> => {
          const result = await this.withClient(
            async (client) =>
              await client.one(
                Queries.gameWithBetStats(sqlFragment`
                  SELECT games.* FROM jasb.games WHERE games.slug = ${gameSlug}
                `),
              ),
          );
          return {
            type: "NewBet",
            game: { slug: result.slug, name: result.name },
            bet: { slug: betSlug, name: betName },
            spoiler,
          };
        }),
      );
      return result;
    });
  }

  async editBet(
    credential: Credentials.Identifying,
    gameSlug: Public.Games.Slug,
    betSlug: Public.Bets.Slug,
    old_version: number,
    name?: string,
    description?: string,
    spoiler?: boolean,
    lockMoment?: string,
    removeOptions?: {
      id: Public.Bets.Options.Slug;
      version: number;
    }[],
    editOptions?: {
      id: Public.Bets.Options.Slug;
      version: number;
      name?: string;
      image?: string | null;
      order?: number;
    }[],
    addOptions?: {
      id: Public.Bets.Options.Slug;
      name: string;
      image: string | null;
      order: number;
    }[],
  ): Promise<Bets.Editable | undefined> {
    const removeArray = Slonik.sql.unnest(
      (removeOptions ?? []).map(({ id, version }) => [id, version]),
      ["text", "int4"],
    );
    const editUnnest = Slonik.sql.unnest(
      (editOptions ?? []).map(({ id, version, name, image, order }) => [
        id,
        version,
        name ?? null,
        image ?? null,
        image === null,
        order ?? null,
      ]),
      ["text", "int4", "text", "text", "bool", "int4"],
    );
    const addUnnest = Slonik.sql.unnest(
      (addOptions ?? []).map(({ id, name, image, order }) => [
        id,
        name,
        image ?? null,
        order,
      ]),
      ["text", "text", "text", "int4"],
    );
    return await this.inTransaction(async (client) => {
      const result = await client.maybeOne(
        Queries.editableBet(sqlFragment`
          SELECT *
          FROM jasb.edit_bet(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${old_version},
            ${gameSlug},
            ${betSlug},
            ${name ?? null},
            ${description ?? null},
            ${spoiler ?? null},
            ${lockMoment ?? null},
            (
              SELECT array_agg(
                row(slug, version)::RemoveOption
              ) FROM ${removeArray} AS removes(slug, version)
            ),
            (
              SELECT array_agg(
                row(slug, version, name, image, remove_image, "order")::EditOption
              ) FROM ${editUnnest} AS edits(slug, version, name, image, remove_image, "order")
            ),
            (
              SELECT array_agg(
                row(slug, name, image, "order")::AddOption
              ) FROM ${addUnnest} AS adds(slug, name, image, "order")
            )
          )
        `),
      );
      return result ?? undefined;
    });
  }

  async setBetLocked(
    credential: Credentials.Identifying,
    gameSlug: Public.Games.Slug,
    betSlug: Public.Bets.Slug,
    old_version: number,
    locked: boolean,
  ): Promise<Bets.Editable | undefined> {
    return await this.inTransaction(async (client) => {
      const result = await client.maybeOne(
        Queries.editableBet(sqlFragment`
          SELECT *
          FROM jasb.set_bet_locked(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${old_version},
            ${gameSlug},
            ${betSlug},
            ${locked}
          )
        `),
      );
      return result ?? undefined;
    });
  }

  async completeBet(
    server: Server.State,
    logger: Logging.Logger,
    credential: Credentials.Identifying,
    gameSlug: Public.Games.Slug,
    betSlug: Public.Bets.Slug,
    old_version: number,
    winners: string[],
  ): Promise<Bets.Editable | undefined> {
    return await this.inTransaction(async (client) => {
      const result = await client.maybeOne(
        Queries.editableBet(sqlFragment`
          SELECT *
          FROM jasb.complete_bet(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${this.#config.rules.gacha.scrapPerRoll},
            ${this.#config.rules.gacha.rewards.winBetRolls},
            ${this.#config.rules.gacha.rewards.loseBetScrap},
            ${old_version},
            ${gameSlug},
            ${betSlug},
            ${Slonik.sql.array(winners, "text")}
          )
        `),
      );
      Background.runTask(
        server,
        logger,
        sendExternalNotification(async (): Promise<Feed.BetComplete> => {
          const row = await this.withClient(
            async (client) =>
              await client.one(
                Queries.betCompleteNotificationDetails(sqlFragment`
                    SELECT bets.*
                    FROM jasb.games INNER JOIN jasb.bets ON games.id = bets.game
                    WHERE games.slug = ${gameSlug} AND bets.slug = ${betSlug}
                `),
              ),
          );
          return {
            type: "BetComplete",
            game: { slug: gameSlug, name: row.game_name },
            bet: { slug: betSlug, name: row.bet_name },
            spoiler: row.spoiler,
            winners: row.winners,
            winningStakes: row.winning_stakes_count,
            totalReturn: row.total_staked_amount,
            highlighted: {
              winners: row.top_winning_users,
              amount: row.biggest_payout_amount,
            },
          };
        }),
      );
      return result ?? undefined;
    });
  }

  async revertCompleteBet(
    credential: Credentials.Identifying,
    gameSlug: Public.Games.Slug,
    betSlug: Public.Bets.Slug,
    old_version: number,
  ): Promise<Bets.Editable | undefined> {
    return await this.inTransaction(async (client) => {
      const result = await client.maybeOne(
        Queries.editableBet(sqlFragment`
          SELECT *
          FROM jasb.revert_complete_bet(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${old_version},
            ${gameSlug},
            ${betSlug}
          )
        `),
      );
      return result ?? undefined;
    });
  }

  async cancelBet(
    credential: Credentials.Identifying,
    gameSlug: Public.Games.Slug,
    betSlug: Public.Bets.Slug,
    old_version: number,
    reason: string,
  ): Promise<Bets.Editable | undefined> {
    return await this.inTransaction(async (client) => {
      const result = await client.maybeOne(
        Queries.editableBet(sqlFragment`
          SELECT *
          FROM jasb.cancel_bet(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${old_version},
            ${gameSlug},
            ${betSlug},
            ${reason}
          )
        `),
      );
      return result ?? undefined;
    });
  }

  async revertCancelBet(
    credential: Credentials.Identifying,
    gameSlug: Public.Games.Slug,
    betSlug: Public.Bets.Slug,
    old_version: number,
  ): Promise<Bets.Editable | undefined> {
    return await this.inTransaction(async (client) => {
      const result = await client.maybeOne(
        Queries.editableBet(sqlFragment`
          SELECT *
          FROM jasb.revert_cancel_bet(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${old_version},
            ${gameSlug},
            ${betSlug}
          )
        `),
      );
      return result ?? undefined;
    });
  }

  async newStake(
    server: Server.State,
    logger: Logging.Logger,
    credential: Credentials.Identifying,
    gameSlug: Public.Games.Slug,
    betSlug: Public.Bets.Slug,
    optionSlug: Public.Bets.Options.Slug,
    amount: number,
    message: string | null,
  ): Promise<number> {
    return await this.inTransaction(async (client) => {
      const row = await client.one(
        Queries.newBalance(sqlFragment`
          SELECT * FROM jasb.new_stake(
            ${this.#config.rules.minStake},
            ${this.#config.rules.notableStake},
            ${this.#config.rules.maxStakeWhileInDebt},
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${gameSlug},
            ${betSlug},
            ${optionSlug},
            ${amount},
            ${message}
          )
        `),
      );
      if (message !== null) {
        Background.runTask(
          server,
          logger,
          sendExternalNotification(async (): Promise<Feed.NotableStake> => {
            const row = await this.withClient(
              async (client) =>
                await client.one(
                  Queries.newStakeNotificationDetails(
                    Credentials.actingUser(credential),
                    sqlFragment`
                      SELECT 
                        options.* 
                      FROM 
                        jasb.games INNER JOIN 
                        jasb.bets ON games.id = bets.game INNER JOIN 
                        jasb.options ON bets.id = options.bet
                      WHERE 
                        games.slug = ${gameSlug} AND 
                        bets.slug = ${betSlug} AND 
                        options.slug = ${optionSlug}
                    `,
                  ),
                ),
            );
            return {
              type: "NotableStake",
              game: { slug: gameSlug, name: row.game_name },
              bet: { slug: betSlug, name: row.bet_name },
              spoiler: row.spoiler,
              option: { slug: optionSlug, name: row.option_name },
              user: row.user_summary,
              message: message,
              stake: amount as Schema.Int,
            };
          }),
        );
      }
      return row.new_balance;
    });
  }

  async withdrawStake(
    credential: Credentials.Identifying,
    gameSlug: Public.Games.Slug,
    betSlug: Public.Bets.Slug,
    optionSlug: Public.Bets.Options.Slug,
  ): Promise<number> {
    return await this.inTransaction(async (client) => {
      const result = await client.one(
        Queries.newBalance(sqlFragment`
          SELECT * FROM jasb.withdraw_stake(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${gameSlug},
            ${betSlug},
            ${optionSlug}
          )
        `),
      );
      return result.new_balance;
    });
  }

  async changeStake(
    credential: Credentials.Identifying,
    gameSlug: Public.Games.Slug,
    betSlug: Public.Bets.Slug,
    optionSlug: Public.Bets.Options.Slug,
    amount: number,
    message: string | null,
  ): Promise<number> {
    return await this.inTransaction(async (client) => {
      const result = await client.one(
        Queries.newBalance(sqlFragment`
          SELECT * FROM jasb.change_stake(
            ${this.#config.rules.minStake},
            ${this.#config.rules.notableStake},
            ${this.#config.rules.maxStakeWhileInDebt},
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${gameSlug},
            ${betSlug},
            ${optionSlug},
            ${amount},
            ${message}
          )
        `),
      );
      return result.new_balance;
    });
  }

  async getNotification(
    credential: Credentials.Identifying,
    notificationId: Public.Notifications.Id,
  ): Promise<Notifications.Notification> {
    return await this.withClient(
      async (client) =>
        await client.one(
          Queries.notification(sqlFragment`
          SELECT * FROM jasb.get_notification(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${notificationId}
          )
        `),
        ),
    );
  }

  async getNotifications(
    credential: Credentials.Identifying,
    includeRead = false,
  ): Promise<readonly Notifications.Notification[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.notification(sqlFragment`
          SELECT * FROM jasb.get_notifications(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${includeRead}
          )
        `),
      );
      return results.rows;
    });
  }

  async clearNotification(
    credential: Credentials.Identifying,
    notificationId: Public.Notifications.Id,
  ): Promise<boolean> {
    const result = await this.inTransaction(
      async (client) =>
        await client.one(
          Queries.isTrue(sqlFragment`
            jasb.set_read(
              ${this.sqlCredential(credential)},
              ${this.#config.auth.sessions.lifetime.toString()},
              ${notificationId}
            )
          `),
        ),
    );
    return result.result;
  }

  async getFeed(): Promise<readonly Feed.Item[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.feedItem(sqlFragment`
          SELECT feed.* FROM jasb.feed
        `),
      );
      return results.rows;
    });
  }

  async getBetFeed(
    gameSlug: Public.Games.Slug,
    betSlug: Public.Bets.Slug,
  ): Promise<readonly Feed.Item[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.feedItem(sqlFragment`
          SELECT feed.* 
          FROM jasb.feed
          WHERE game_slug = ${gameSlug} AND bet_slug = ${betSlug}
        `),
      );
      return results.rows;
    });
  }

  async getPermissions(
    userSlug: Public.Users.Slug,
  ): Promise<Users.Permissions> {
    return await this.withClient(async (client) => {
      return await client.one(
        Queries.permissions(sqlFragment`
          SELECT users.* FROM jasb.users WHERE users.slug = ${userSlug}
        `),
      );
    });
  }

  async setPermissions(
    credential: Credentials.Identifying,
    targetUserSlug: Public.Users.Slug,
    gameSlug: Public.Games.Slug | undefined,
    manage_games: boolean | undefined,
    manage_permissions: boolean | undefined,
    manage_gacha: boolean | undefined,
    manage_bets: boolean | undefined,
  ): Promise<Users.Permissions> {
    return await this.inTransaction(async (client) => {
      await client.query(
        Queries.perform(sqlFragment`
          jasb.set_permissions(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${targetUserSlug},
            ${gameSlug ?? null},
            ${manage_games ?? null},
            ${manage_permissions ?? null},
            ${manage_gacha ?? null},
            ${manage_bets ?? null}
          )
        `),
      );
      return await client.one(
        Queries.permissions(sqlFragment`
          SELECT users.* FROM jasb.users WHERE users.slug = ${targetUserSlug}
        `),
      );
    });
  }

  async gachaGetForgeDetail(
    userSlug: Public.Users.Slug,
  ): Promise<Users.ForgeDetail> {
    return await this.withClient(
      async (client) =>
        await client.one(
          Queries.userForgeDetail(sqlFragment`
            SELECT users.* FROM users WHERE users.slug = ${userSlug}
          `),
        ),
    );
  }

  async gachaRetireForgedCardType(
    credential: Credentials.Identifying,
    cardTypeId: Public.Gacha.CardTypes.Id,
  ): Promise<Gacha.CardType> {
    return await this.inTransaction(
      async (client) =>
        await client.one(
          Queries.cardType(sqlFragment`
          SELECT * FROM jasb.gacha_retire_forged(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${cardTypeId}
          )
        `),
        ),
    );
  }

  async gachaForgeCardType(
    credential: Credentials.Identifying,
    cardName: string,
    cardImageObjectReference: Objects.Reference,
    cardImageUrl: string,
    cardImageSourceUrl: string | null,
    cardQuote: string,
    cardRaritySlug: Public.Gacha.Rarities.Slug,
  ): Promise<Public.Gacha.CardTypes.Id> {
    const result = await this.inTransaction(
      async (client) =>
        await client.one(
          Queries.id(sqlFragment`
            SELECT * FROM jasb.gacha_forge_card_type(
              ${this.sqlCredential(credential)},
              ${this.#config.auth.sessions.lifetime.toString()},
              ${cardName},
              ${cardImageObjectReference.name},
              ${cardImageUrl},
              ${cardImageSourceUrl},
              ${cardQuote},
              ${cardRaritySlug}
            )
          `),
        ),
    );
    return result.id as Public.Gacha.CardTypes.Id;
  }

  async gachaGetUserForgeCardsTypes(
    userSlug: Public.Users.Slug,
  ): Promise<readonly Gacha.CardTypes.OptionalForRarity[]> {
    return await this.withClient(async (client) => {
      const result = await client.query(
        Queries.cardTypeByRarity(sqlFragment`
          SELECT
            card_types.* 
          FROM
            jasb.gacha_card_types AS card_types INNER JOIN
            jasb.users ON card_types.forged_by = users.id
          WHERE 
            users.slug = ${userSlug} AND
            NOT card_types.retired
        `),
      );
      return result.rows;
    });
  }

  async gachaGetCollectionCards(
    userSlug: Public.Users.Slug,
    bannerSlug: Public.Gacha.Banners.Slug,
  ): Promise<readonly Gacha.CardTypes.WithCards[]> {
    return await this.withClient(async (client) => {
      const result = await client.query(
        Queries.cardTypeWithCards(
          sqlFragment`
            SELECT 
              cards.* 
            FROM 
              jasb.gacha_cards AS cards INNER JOIN 
              jasb.users ON cards.owner = users.id INNER JOIN
              jasb.gacha_card_types AS card_types ON 
                cards.type = card_types.id INNER JOIN
              jasb.gacha_banners AS banners ON card_types.banner = banners.id
            WHERE 
              users.slug = ${userSlug} AND 
              banners.slug = ${bannerSlug}
          `,
          bannerSlug,
        ),
      );
      return result.rows;
    });
  }

  async gachaGetDetailedCard(
    userSlug: Public.Users.Slug,
    cardId: Public.Gacha.Cards.Id,
  ): Promise<Gacha.Cards.Detailed> {
    return await this.withClient(async (client) => {
      return await client.one(
        Queries.detailedCard(sqlFragment`
          SELECT 
            cards.* 
          FROM 
            jasb.gacha_cards AS cards INNER JOIN 
            jasb.users ON cards.owner = users.id
          WHERE users.slug = ${userSlug} AND cards.id = ${cardId}
        `),
      );
    });
  }

  async gachaGetHighlighted(
    userSlug: Public.Users.Slug,
  ): Promise<readonly Gacha.Cards.Highlighted[]> {
    return await this.withClient(async (client) => {
      const result = await client.query(
        Queries.highlighted(sqlFragment`
          SELECT 
            highlights.* 
          FROM 
            jasb.gacha_card_highlights AS highlights INNER JOIN
            jasb.users ON highlights.owner = users.id
          WHERE users.slug = ${userSlug}
        `),
      );
      return result.rows;
    });
  }

  async gachaSetHighlight(
    credential: Credentials.Identifying,
    cardId: Public.Gacha.Cards.Id,
    highlighted: boolean,
  ): Promise<Gacha.Cards.Highlighted> {
    return await this.inTransaction(async (client) => {
      return await client.one(
        Queries.highlighted(sqlFragment`
          SELECT *
          FROM jasb.gacha_set_highlight(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${cardId},
            ${highlighted}
          )
        `),
      );
    });
  }

  async gachaEditHighlight(
    credential: Credentials.Identifying,
    cardId: Public.Gacha.Cards.Id,
    message?: string | null,
  ): Promise<Gacha.Cards.Highlighted> {
    return await this.inTransaction(async (client) => {
      return await client.one(
        Queries.highlighted(sqlFragment`
          SELECT * FROM jasb.gacha_edit_highlight(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${cardId},
            ${message ?? null},
            ${message === null}
          )
        `),
      );
    });
  }

  async gachaSetHighlightsOrder(
    credential: Credentials.Identifying,
    order: readonly number[],
  ): Promise<readonly Gacha.Cards.Highlighted[]> {
    return await this.inTransaction(async (client) => {
      const result = await client.query(
        Queries.highlighted(sqlFragment`
            SELECT * FROM jasb.gacha_reorder_highlights(
              ${this.sqlCredential(credential)},
              ${this.#config.auth.sessions.lifetime.toString()},
              ${Slonik.sql.array(order, "int4")}
            )
        `),
      );
      return result.rows;
    });
  }

  async gachaRoll(
    credential: Credentials.Identifying,
    bannerSlug: Public.Gacha.Banners.Slug,
    count: number,
    guarantee: boolean,
  ): Promise<readonly Gacha.Cards.Card[]> {
    return await this.inTransaction(async (client) => {
      const result = await client.query(
        Queries.ids(
          sqlFragment`
            SELECT id
            FROM jasb.gacha_roll(
              ${this.sqlCredential(credential)},
              ${this.#config.auth.sessions.lifetime.toString()},
              ${this.#config.rules.gacha.maxPity},
              ${bannerSlug}, 
              ${count}, 
              ${guarantee}
            )
          `,
        ),
      );
      const finalResult = await client.query(
        Queries.card(
          sqlFragment`
            SELECT * FROM gacha_cards 
            WHERE id = ${this.anyOf(result.rows)}`,
          false,
        ),
      );
      return finalResult.rows;
    });
  }

  async gachaRecycleValue(
    userSlug: Public.Users.Slug,
    bannerSlug: Public.Gacha.Banners.Slug,
    cardId: Public.Gacha.Cards.Id,
  ): Promise<Gacha.Balances.Value> {
    return await this.inTransaction(async (client) => {
      return await client.one(
        Queries.recycleValue(sqlFragment`
          SELECT 
            gacha_cards.* 
          FROM 
            gacha_cards INNER JOIN
            gacha_card_types ON gacha_cards.type = gacha_card_types.id INNER JOIN
            gacha_banners ON gacha_card_types.banner = gacha_banners.id INNER JOIN
            users ON gacha_cards.owner = users.id
          WHERE 
            gacha_cards.id = ${cardId} AND
            gacha_banners.slug = ${bannerSlug} AND
            users.slug = ${userSlug} 
        `),
      );
    });
  }

  async gachaRecycleCard(
    credential: Credentials.Identifying,
    cardId: Public.Gacha.Cards.Id,
  ): Promise<Gacha.Balance> {
    return await this.inTransaction(async (client) => {
      return await client.one(
        Queries.balance(sqlFragment`
          SELECT * FROM jasb.gacha_recycle_card(
            ${this.sqlCredential(credential)},
            ${this.#config.auth.sessions.lifetime.toString()},
            ${this.#config.rules.gacha.scrapPerRoll},
            ${cardId}
          )
        `),
      );
    });
  }

  async gachaGetBalance(
    credential: Credentials.Identifying,
  ): Promise<Gacha.Balances.Balance> {
    const result = await this.withClient(
      async (client) =>
        await client.maybeOne(
          Queries.balance(sqlFragment`
          SELECT * FROM jasb.gacha_get_balance(
              ${this.sqlCredential(credential)},
              ${this.#config.auth.sessions.lifetime.toString()}
            )
          `),
        ),
    );
    return (
      result ?? {
        rolls: 0 as Schema.Int,
        pity: 0 as Schema.Int,
        guarantees: 0 as Schema.Int,
        scrap: 0 as Schema.Int,
      }
    );
  }

  async gachaGetRarities(): Promise<readonly Gacha.Rarities.Rarity[]> {
    const result = await this.withClient(
      async (client) =>
        await client.query(
          Queries.rarity(sqlFragment`
            SELECT * FROM gacha_rarities
          `),
        ),
    );
    return result.rows;
  }

  async gachaGetQualities(): Promise<readonly Gacha.Qualities.Quality[]> {
    const result = await this.withClient(
      async (client) =>
        await client.query(
          Queries.quality(sqlFragment`
            SELECT * FROM gacha_qualities
          `),
        ),
    );
    return result.rows;
  }

  async gachaGetBanners(): Promise<readonly Gacha.Banners.Banner[]> {
    return await this.withClient(async (client) => {
      const result = await client.query(
        Queries.banner(sqlFragment`
          SELECT banners.* 
          FROM jasb.gacha_banners AS banners 
          WHERE banners.active
        `),
      );
      return result.rows;
    });
  }

  async gachaGetEditableBanners(): Promise<readonly Gacha.Banners.Editable[]> {
    return await this.withClient(async (client) => {
      const result = await client.query(
        Queries.editableBanner(sqlFragment`
          SELECT banners.* 
          FROM jasb.gacha_banners AS banners 
        `),
      );
      return result.rows;
    });
  }

  async gachaGetBanner(
    bannerSlug: string,
  ): Promise<Gacha.Banners.Banner | undefined> {
    const result = await this.withClient(
      async (client) =>
        await client.maybeOne(
          Queries.banner(sqlFragment`
            SELECT banners.* 
            FROM jasb.gacha_banners AS banners 
            WHERE banners.slug = ${bannerSlug}
          `),
        ),
    );
    return result ?? undefined;
  }

  async gachaGetEditableBanner(
    bannerSlug: string,
  ): Promise<Gacha.Banners.Editable | undefined> {
    const result = await this.withClient(
      async (client) =>
        await client.maybeOne(
          Queries.editableBanner(sqlFragment`
            SELECT banners.* 
            FROM jasb.gacha_banners AS banners 
            WHERE banners.slug = ${bannerSlug}
          `),
        ),
    );
    return result ?? undefined;
  }

  async gachaGetCollectionBanners(
    userSlug: Public.Users.Slug,
  ): Promise<readonly Gacha.Banners.Editable[]> {
    return await this.withClient(async (client) => {
      const result = await client.query(
        Queries.editableBanner(sqlFragment`
          SELECT DISTINCT ON (banners.id) banners.* 
          FROM 
            jasb.gacha_cards AS cards INNER JOIN
            jasb.gacha_card_types AS card_types ON 
              cards.type = card_types.id INNER JOIN
            jasb.gacha_banners AS banners ON 
              card_types.banner = banners.id INNER JOIN
            jasb.users ON cards.owner = users.id
          WHERE users.slug = ${userSlug}
        `),
      );
      return result.rows;
    });
  }

  async gachaAddBanner(
    credential: Credentials.Identifying,
    bannerSlug: string,
    name: string,
    description: string,
    cover: string,
    active: boolean,
    type: string,
    backgroundColor: Buffer,
    foregroundColor: Buffer,
  ): Promise<number> {
    const result = await this.inTransaction(
      async (client) =>
        await client.one(
          Queries.id(sqlFragment`
             SELECT * FROM jasb.gacha_add_banner(
               ${this.sqlCredential(credential)},
               ${this.#config.auth.sessions.lifetime.toString()},
               ${bannerSlug},
               ${name},
               ${description},
               ${cover},
               ${active},
               ${type},
               ${Slonik.sql.binary(backgroundColor)},
               ${Slonik.sql.binary(foregroundColor)}
             )
          `),
        ),
    );
    return result.id;
  }

  async gachaEditBanner(
    credential: Credentials.Identifying,
    bannerSlug: string,
    oldVersion: number,
    name: string | null,
    description: string | null,
    cover: string | null,
    active: boolean | null,
    type: string | null,
    backgroundColor: Buffer | null,
    foregroundColor: Buffer | null,
  ): Promise<number> {
    const result = await this.inTransaction(
      async (client) =>
        await client.one(
          Queries.id(sqlFragment`
            SELECT * FROM jasb.gacha_edit_banner(
              ${this.sqlCredential(credential)},
              ${this.#config.auth.sessions.lifetime.toString()},
              ${bannerSlug},
              ${oldVersion},
              ${name},
              ${description},
              ${cover},
              ${active},
              ${type},
              ${
                backgroundColor !== null
                  ? Slonik.sql.binary(backgroundColor)
                  : null
              },
              ${
                foregroundColor !== null
                  ? Slonik.sql.binary(foregroundColor)
                  : null
              }
            )
          `),
        ),
    );
    return result.id;
  }

  async gachaReorderBanners(
    credential: Credentials.Identifying,
    order: readonly [string, number][],
  ): Promise<readonly Gacha.Banners.Editable[]> {
    return await this.inTransaction(async (client) => {
      const orderUnnest = Slonik.sql.unnest(order, ["text", "int4"]);
      const result = await client.query(
        Queries.editableBanner(sqlFragment`
           SELECT * FROM jasb.gacha_reorder_banners(
             ${this.sqlCredential(credential)},
             ${this.#config.auth.sessions.lifetime.toString()},
             (SELECT array_agg(
               row(slug, version)::jasb.OrderedBanner
             ) FROM ${orderUnnest} AS new_order(slug, version))
           )
        `),
      );
      return result.rows;
    });
  }

  async gachaGetCardTypes(
    bannerSlug: Public.Gacha.Banners.Slug,
  ): Promise<readonly Gacha.CardTypes.CardType[]> {
    const result = await this.withClient(
      async (client) =>
        await client.query(
          Queries.cardType(sqlFragment`
            SELECT 
              card_types.* 
            FROM 
              jasb.gacha_card_types AS card_types INNER JOIN 
              jasb.gacha_banners AS banners ON card_types.banner = banners.id 
            WHERE 
              banners.slug = ${bannerSlug}
          `),
        ),
    );
    return result.rows;
  }

  async gachaGetEditableCardTypes(
    bannerSlug: Public.Gacha.Banners.Slug,
  ): Promise<readonly Gacha.CardTypes.Editable[]> {
    const result = await this.withClient(
      async (client) =>
        await client.query(
          Queries.editableCardType(sqlFragment`
            SELECT 
              card_types.* 
            FROM 
              jasb.gacha_card_types AS card_types INNER JOIN 
              jasb.gacha_banners AS banners ON card_types.banner = banners.id 
            WHERE 
              banners.slug = ${bannerSlug}
          `),
        ),
    );
    return result.rows;
  }

  async gachaGetCardType(
    cardTypeId: Public.Gacha.CardTypes.Id,
    bannerSlug?: Public.Gacha.Banners.Slug,
  ): Promise<Gacha.CardTypes.Detailed | undefined> {
    const bannerSlugOrNull = bannerSlug ?? null;
    const result = await this.withClient(
      async (client) =>
        await client.maybeOne(
          Queries.detailedCardType(sqlFragment`
            SELECT 
              card_types.* 
            FROM 
              jasb.gacha_card_types AS card_types INNER JOIN 
              jasb.gacha_banners AS banners ON card_types.banner = banners.id 
            WHERE 
              (${bannerSlugOrNull}::TEXT IS NULL OR banners.slug = ${bannerSlugOrNull}::TEXT) AND
              card_types.id = ${cardTypeId}
          `),
        ),
    );
    return result ?? undefined;
  }

  async gachaGiftSelfMadeCard(
    credential: Credentials.Identifying,
    giftToUserSlug: Public.Users.Slug,
    bannerSlug: Public.Gacha.Banners.Slug,
    cardTypeId: Public.Gacha.CardTypes.Id,
  ): Promise<Gacha.Cards.Card> {
    return await this.inTransaction(async (client) => {
      return await client.one(
        Queries.card(
          sqlFragment`
            SELECT * FROM jasb.gacha_gift_self_made(
              ${this.sqlCredential(credential)},
              ${this.#config.auth.sessions.lifetime.toString()},
              ${giftToUserSlug},
              ${bannerSlug},
              ${cardTypeId}
            )
          `,
          false,
        ),
      );
    });
  }

  async gachaAddCardType(
    credential: Credentials.Identifying,
    bannerSlug: Public.Gacha.Banners.Slug,
    name: string,
    description: string,
    image: string,
    raritySlug: Public.Gacha.Rarities.Slug,
    layout: Public.Gacha.Cards.Layout,
    credits: readonly {
      reason: string;
      credited: {
        user?: Public.Users.Slug;
        name?: string;
      };
    }[],
  ): Promise<number> {
    const result = await this.inTransaction(async (client) => {
      const addUnnest = Slonik.sql.unnest(
        credits.map(({ reason, credited: { user, name } }) => [
          reason,
          user ?? null,
          name ?? null,
        ]),
        ["text", "text", "text"],
      );
      return await client.one(
        Queries.id(sqlFragment`
           SELECT * FROM jasb.gacha_add_card_type(
             ${this.sqlCredential(credential)},
             ${this.#config.auth.sessions.lifetime.toString()},
             ${bannerSlug},
             ${name},
             ${description},
             ${image},
             ${raritySlug},
             ${layout},
             (
               SELECT array_agg(
                 row(reason, "user", name)::AddCredit
               ) FROM ${addUnnest} AS adds(reason, "user", name)
             )
           )
        `),
      );
    });
    return result.id;
  }

  async gachaEditCardType(
    credential: Credentials.Identifying,
    bannerSlug: Public.Gacha.Banners.Slug,
    cardTypeId: Public.Gacha.CardTypes.Id,
    oldVersion: number,
    name: string | null,
    description: string | null,
    image: string | null,
    raritySlug: Public.Gacha.Rarities.Slug | null,
    layout: Public.Gacha.Cards.Layout | null,
    retired: boolean | null,
    removeCredits: readonly {
      id: Public.Gacha.Credits.Id;
      version: number;
    }[],
    editCredits: readonly {
      id: Public.Gacha.Credits.Id;
      reason?: string | null;
      credited?: { user?: Public.Users.Slug | null; name?: string | null };
      version: number;
    }[],
    addCredits: readonly {
      reason: string;
      credited: {
        user?: Public.Users.Slug | null;
        name?: string | null;
      };
    }[],
  ): Promise<number> {
    return await this.inTransaction(async (client) => {
      const removeUnnest = Slonik.sql.unnest(
        removeCredits.map(({ id, version }) => [id, version]),
        ["int4", "int4"],
      );
      const editUnnest = Slonik.sql.unnest(
        editCredits.map(({ id, reason, credited, version }) => [
          id,
          reason ?? null,
          credited?.user ?? null,
          credited?.name ?? null,
          version,
        ]),
        ["int4", "text", "text", "text", "int4"],
      );
      const addUnnest = Slonik.sql.unnest(
        addCredits.map(({ reason, credited }) => [
          reason,
          credited.user ?? null,
          credited.name ?? null,
        ]),
        ["text", "text", "text"],
      );
      const result = await client.one(
        Queries.ids(sqlFragment`
           SELECT id FROM jasb.gacha_edit_card_type(
             ${this.sqlCredential(credential)},
             ${this.#config.auth.sessions.lifetime.toString()},
             ${bannerSlug},
             ${cardTypeId},
             ${oldVersion},
             ${name},
             ${description},
             ${image},
             ${raritySlug},
             ${layout},
             ${retired},
             (
               SELECT array_agg(
                 row(id, version)::RemoveCredit
               ) FROM ${removeUnnest} AS removes(id, version)
             ),
             (
               SELECT array_agg(
                 row(id, reason, "user", name, version)::EditCredit
               ) FROM ${editUnnest} AS edits(id, reason, "user", name, version)
             ),
             (
               SELECT array_agg(
                 row(reason, "user", name)::AddCredit
               ) FROM ${addUnnest} AS adds(reason, "user", name)
             )
           )
        `),
      );
      return result.id;
    });
  }

  async gachaGetEditableCardType(
    id: number,
  ): Promise<Gacha.CardTypes.Editable> {
    return await this.withClient(
      async (client) =>
        await client.one(
          Queries.editableCardType(sqlFragment`
           SELECT *
           FROM jasb.gacha_card_types
           WHERE gacha_card_types.id = ${id}
        `),
        ),
    );
  }

  async garbageCollectSessions(): Promise<readonly string[]> {
    return await this.inTransaction(async (client) => {
      const results = await client.query(
        Queries.accessToken(sqlFragment`
          DELETE FROM
            jasb.sessions
          WHERE
            NOW() >= (started + ${this.#config.auth.sessions.lifetime.toString()}::INTERVAL)
          RETURNING sessions.*
        `),
      );
      return results.rows.map((row) => row.access_token);
    });
  }

  async objectReferenceFindUncached(
    max: number,
    type: Objects.TypeName,
    table: Slonik.IdentifierSqlToken,
    column: Slonik.IdentifierSqlToken,
  ): Promise<readonly { id: number; url: string }[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.object(sqlFragment`
          SELECT objects.id, objects.url, objects.name, objects.source_url
          FROM 
            ${table} INNER JOIN 
            objects ON ${column} = objects.id AND objects.type = ${type}::ObjectType
          WHERE objects.name IS NULL AND objects.store_failures < 10
          LIMIT ${max}
        `),
      );
      return results.rows.map(({ id, url }) => ({
        id,
        url,
      }));
    });
  }

  async objectReferenceUpdateCached(
    typeName: Objects.TypeName,
    updates: Iterable<{
      id: number;
      name: string;
      oldUrl: string;
      url: string;
    }>,
  ): Promise<number> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.object(sqlFragment`
          UPDATE objects
          SET 
            name = updates.name,
            url = updates.url 
          FROM ${Slonik.sql.unnest(
            [
              ...Iterables.map(updates, ({ id, oldUrl, name, url }) => [
                id,
                oldUrl,
                name,
                url,
              ]),
            ],
            ["int4", "text", "text", "text"],
          )} AS updates(id, old_url, name, url)
          WHERE 
            objects.id = updates.id AND
            objects.type = ${typeName}::ObjectType AND
            objects.url = updates.old_url AND 
            objects.name IS NULL
          RETURNING objects.id, objects.url, objects.name, objects.source_url
        `),
      );
      return results.rowCount;
    });
  }

  async objectReferenceIncrementFailure(
    typeName: Objects.TypeName,
    id: number,
  ): Promise<number> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.object(sqlFragment`
          UPDATE objects 
          SET store_failures = objects.store_failures + 1
          WHERE objects.id = ${id} AND objects.type = ${typeName}::ObjectType 
          RETURNING objects.id, objects.url, objects.name, objects.source_url
        `),
      );
      return results.rowCount;
    });
  }

  async objectsWithoutReferences(
    typeName: Objects.TypeName,
    objects: readonly Objects.Reference[],
  ): Promise<readonly Objects.Reference[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.name(sqlFragment`
          SELECT name
          FROM 
            ${Slonik.sql.unnest(
              objects.map(({ name }) => [name]),
              ["text"],
            )} AS searching_for(name) 
          WHERE NOT EXISTS (
            SELECT name 
            FROM objects 
            WHERE 
              searching_for.name = objects.name AND 
              objects.type = ${typeName}::ObjectType
          )
        `),
      );
      return results.rows;
    });
  }

  async objectsDeleteUnusedReferences(
    typeName: Objects.TypeName,
    table: Slonik.IdentifierSqlToken,
    column: Slonik.IdentifierSqlToken,
  ): Promise<number> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.object(sqlFragment`
          DELETE FROM objects
          WHERE
            objects.type = ${typeName}::ObjectType AND
            NOT EXISTS (
              SELECT ${column}
              FROM ${table}
              WHERE ${column} = objects.id
            ) RETURNING objects.id, objects.url, objects.name, objects.source_url
        `),
      );
      return results.rowCount;
    });
  }

  async unload(): Promise<void> {
    await this.#pool.end();
  }

  private async withClient<Value>(
    operation: (client: Slonik.DatabasePoolConnection) => Promise<Value>,
  ): Promise<Value> {
    return await Store.translatingErrors(
      async () => await this.#pool.connect(operation),
    );
  }

  private async inTransaction<Value>(
    operation: (client: Slonik.DatabaseTransactionConnection) => Promise<Value>,
  ): Promise<Value> {
    return await Store.translatingErrors(
      async () => await this.#pool.transaction(operation),
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
      if (error instanceof Slonik.NotFoundError) {
        throw new WebError(StatusCodes.NOT_FOUND, "Not Found");
      }
      if (error.code !== undefined) {
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
