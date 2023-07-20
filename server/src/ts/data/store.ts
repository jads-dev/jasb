import type * as Joda from "@js-joda/core";
import { StatusCodes } from "http-status-codes";
import { default as Slonik, type SerializableValue } from "slonik";

import {
  AvatarCache,
  Bets,
  Feed,
  Games,
  Notifications,
  Users,
} from "../internal.js";
import type { Config } from "../server/config.js";
import { WebError } from "../server/errors.js";
import type { Logging } from "../server/logging.js";
import { Notifier } from "../server/notifier.js";
import { SecretToken } from "../util/secret-token.js";
import type { ObjectUploader } from "./object-upload.js";
import { Queries } from "./store/queries.js";

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
    return new Store(
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
  }

  async validateManageGamesOrBets(
    userSlug: string,
    sessionId: SecretToken,
  ): Promise<string> {
    return await this.withClient(async (client) => {
      if (
        await client.query(
          Queries.isTrue(sqlFragment`
            jasb.validate_manage_games_or_bets(
              ${userSlug},
              ${sessionId.uri},
              ${this.config.auth.sessionLifetime.toString()}
            )
          `),
        )
      ) {
        return userSlug;
      } else {
        throw new WebError(StatusCodes.FORBIDDEN, "Not a bet manager.");
      }
    });
  }

  async getUser(
    slug: string,
    sessionId?: SecretToken,
  ): Promise<Users.User | undefined> {
    return await this.withClient(async (client) => {
      if (sessionId !== undefined) {
        if (
          !(await client.query(
            Queries.isTrue(sqlFragment`
              jasb.validate_session(
                ${slug},
                ${sessionId.uri},
                ${this.config.auth.sessionLifetime.toString()}
              );
            `),
          ))
        ) {
          throw new WebError(StatusCodes.UNAUTHORIZED, "Must be logged in.");
        }
      }
      const result = await client.maybeOne(
        Queries.user(sqlFragment`
          SELECT users.* FROM users WHERE users.slug = ${slug}
        `),
      );
      return result ?? undefined;
    });
  }

  async getNetWorthLeaderboard(): Promise<readonly Users.Leaderboard[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.leaderboard(sqlFragment`
          SELECT leaderboard.* 
          FROM jasb.leaderboard
          WHERE net_worth > ${this.config.rules.initialBalance}
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

  async bankruptcyStats(userSlug: string): Promise<Users.BankruptcyStats> {
    return await this.withClient(async (client) => {
      return await client.one(
        Queries.bankruptcyStats(
          this.config.rules.initialBalance,
          sqlFragment`
            SELECT * from jasb.users WHERE users.slug = ${userSlug}
          `,
        ),
      );
    });
  }

  async bankrupt(
    userSlug: string,
    sessionId: SecretToken,
  ): Promise<Users.User> {
    return await this.inTransaction(async (client) => {
      return await client.one(
        Queries.user(sqlFragment`
          SELECT * FROM jasb.bankrupt(
            ${userSlug},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${this.config.rules.initialBalance}
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
    discordExpiresIn: Joda.Duration,
  ): Promise<{
    user: Users.User & Users.LoginDetail;
    notifications: readonly Notifications.Notification[];
  }> {
    const sessionId = await SecretToken.secureRandom(
      this.config.auth.sessionIdSize,
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
              ${discordExpiresIn.toString()},
              ${this.config.rules.initialBalance}
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
    userSlug: string,
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

  async getGame(
    slug: string,
  ): Promise<(Games.Game & Games.BetStats) | undefined> {
    return await this.withClient(async (client) => {
      const result = await client.maybeOne(
        Queries.gameWithBetStats(sqlFragment`
          SELECT games.* FROM jasb.games WHERE games.slug = ${slug}
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
    creatorSlug: string,
    sessionId: SecretToken,
    slug: string,
    name: string,
    cover: string,
    started: Joda.LocalDate | null,
    finished: Joda.LocalDate | null,
    order: number | null,
  ): Promise<Games.Game> {
    return await this.inTransaction(async (client) => {
      return await client.one(
        Queries.gameWithBetStats(sqlFragment`
          SELECT * FROM jasb.add_game(
            ${creatorSlug},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${slug},
            ${name},
            ${cover},
            ${started?.toString() ?? null},
            ${finished?.toString() ?? null},
            ${order}
          ) AS games
      `),
      );
    });
  }

  async editGame(
    editor: string,
    sessionId: SecretToken,
    version: number,
    id: string,
    name?: string,
    cover?: string,
    started?: Joda.LocalDate | null,
    finished?: Joda.LocalDate | null,
    order?: number | null,
  ): Promise<Games.Game & Games.BetStats> {
    return await this.inTransaction(async (client) => {
      return await client.one(
        Queries.gameWithBetStats(sqlFragment`
          SELECT * FROM jasb.edit_game(
            ${editor},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${id},
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
      );
    });
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
    authorSlug: string,
    sessionId: SecretToken,
    gameSlug: string,
    remove?: readonly { id: string; version: number }[],
    edit?: readonly {
      id: string;
      version: number;
      name?: string;
      order?: number;
    }[],
    add?: readonly {
      id: string;
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
            ${authorSlug},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
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
    gameSlug: string,
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
    gameSlug: string,
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
    userSlug: string,
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
    gameSlug: string,
    betSlug: string,
  ): Promise<Bets.EditableBet | undefined> {
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
    authorSlug: string,
    sessionId: SecretToken,
    gameSlug: string,
    betSlug: string,
    betName: string,
    description: string,
    spoiler: boolean,
    lockMomentSlug: string,
    options: {
      id: string;
      name: string;
      image: string | null;
    }[],
  ): Promise<Bets.EditableBet> {
    const addUnnest = Slonik.sql.unnest(
      options.map(({ id, name, image }) => [id, name, image ?? null]),
      ["text", "text", "text"],
    );
    return await this.inTransaction(async (client) => {
      const result = await client.one(
        Queries.editableBet(sqlFragment`
          SELECT *
          FROM jasb.add_bet(
            ${authorSlug},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
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
      await this.notifier.notify(async () => {
        const result = await client.one(
          Queries.gameWithBetStats(sqlFragment`
            SELECT games.* FROM jasb.games WHERE games.slug = ${gameSlug}
          `),
        );
        return Notifier.newBet(
          this.config.clientOrigin,
          spoiler,
          gameSlug,
          result.name,
          betSlug,
          betName,
        );
      });
      return result;
    });
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
    lockMoment?: string,
    removeOptions?: {
      id: string;
      version: number;
    }[],
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
  ): Promise<Bets.EditableBet | undefined> {
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
            ${editor},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${old_version},
            ${gameId},
            ${id},
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
    editor: string,
    sessionId: SecretToken,
    gameId: string,
    id: string,
    old_version: number,
    locked: boolean,
  ): Promise<Bets.EditableBet | undefined> {
    return await this.inTransaction(async (client) => {
      const result = await client.maybeOne(
        Queries.editableBet(sqlFragment`
          SELECT *
          FROM jasb.set_bet_locked(
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
      return result ?? undefined;
    });
  }

  async completeBet(
    userSlug: string,
    sessionId: SecretToken,
    gameSlug: string,
    betSlug: string,
    old_version: number,
    winners: string[],
  ): Promise<Bets.EditableBet | undefined> {
    return await this.inTransaction(async (client) => {
      const result = await client.maybeOne(
        Queries.editableBet(sqlFragment`
          SELECT *
          FROM jasb.complete_bet(
            ${userSlug},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${old_version},
            ${gameSlug},
            ${betSlug},
            ${Slonik.sql.array(winners, "text")}
          )
        `),
      );
      await this.notifier.notify(async () => {
        const row = await client.one(
          Queries.betCompleteNotificationDetails(sqlFragment`
            SELECT bets.* 
            FROM jasb.games INNER JOIN jasb.bets ON games.id = bets.game 
            WHERE games.slug = ${gameSlug} AND bets.slug = ${betSlug}
          `),
        );
        return Notifier.betComplete(
          this.config.clientOrigin,
          row.spoiler,
          gameSlug,
          row.game_name,
          betSlug,
          row.bet_name,
          winners,
          row.winning_stakes_count,
          row.total_staked_amount,
          row.top_winning_discord_ids,
          row.biggest_payout_amount,
        );
      });
      return result ?? undefined;
    });
  }

  async revertCompleteBet(
    userSlug: string,
    sessionId: SecretToken,
    gameSlug: string,
    betSlug: string,
    old_version: number,
  ): Promise<Bets.EditableBet | undefined> {
    return await this.inTransaction(async (client) => {
      const result = await client.maybeOne(
        Queries.editableBet(sqlFragment`
          SELECT *
          FROM jasb.revert_complete_bet(
            ${userSlug},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
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
    userSlug: string,
    sessionId: SecretToken,
    gameSlug: string,
    betSlug: string,
    old_version: number,
    reason: string,
  ): Promise<Bets.EditableBet | undefined> {
    return await this.inTransaction(async (client) => {
      const result = await client.maybeOne(
        Queries.editableBet(sqlFragment`
          SELECT *
          FROM jasb.cancel_bet(
            ${userSlug},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
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
    userSlug: string,
    sessionId: SecretToken,
    gameSlug: string,
    betSlug: string,
    old_version: number,
  ): Promise<Bets.EditableBet | undefined> {
    return await this.inTransaction(async (client) => {
      const result = await client.maybeOne(
        Queries.editableBet(sqlFragment`
          SELECT *
          FROM jasb.revert_cancel_bet(
            ${userSlug},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
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
    userSlug: string,
    sessionId: SecretToken,
    gameSlug: string,
    betSlug: string,
    optionSlug: string,
    amount: number,
    message: string | null,
  ): Promise<number> {
    return await this.inTransaction(async (client) => {
      const row = await client.one(
        Queries.newBalance(sqlFragment`
          SELECT * FROM jasb.new_stake(
            ${this.config.rules.minStake},
            ${this.config.rules.notableStake},
            ${this.config.rules.maxStakeWhileInDebt},
            ${userSlug},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${gameSlug},
            ${betSlug},
            ${optionSlug},
            ${amount},
            ${message}
          )
        `),
      );
      if (message !== null) {
        await this.notifier.notify(async () => {
          const row = await client.one(
            Queries.newStakeNotificationDetails(
              userSlug,
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
          );
          return Notifier.newStake(
            this.config.clientOrigin,
            row.spoiler,
            gameSlug,
            row.game_name,
            betSlug,
            row.bet_name,
            row.option_name,
            row.user_discord_id,
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
      const result = await client.one(
        Queries.newBalance(sqlFragment`
          SELECT * FROM jasb.withdraw_stake(
            ${userId},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${gameId},
            ${betId},
            ${optionId}
          )
        `),
      );
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
      const result = await client.one(
        Queries.newBalance(sqlFragment`
          SELECT * FROM jasb.change_stake(
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
          )
        `),
      );
      return result.new_balance;
    });
  }

  async getNotifications(
    slug: string,
    sessionId: SecretToken,
    includeRead = false,
  ): Promise<readonly Notifications.Notification[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.notification(sqlFragment`
          SELECT * FROM jasb.get_notifications(
            ${slug},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${includeRead}
          )
        `),
      );
      return results.rows;
    });
  }

  async clearNotification(
    userId: string,
    sessionId: SecretToken,
    id: string,
  ): Promise<boolean> {
    const result = await this.inTransaction(
      async (client) =>
        await client.one(
          Queries.isTrue(sqlFragment`
            jasb.set_read(
              ${userId},
              ${sessionId.uri},
              ${this.config.auth.sessionLifetime.toString()},
              ${id}
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
    gameSlug: string,
    betSlug: string,
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

  async getPermissions(userSlug: string): Promise<Users.EditablePermissions> {
    return await this.withClient(async (client) => {
      return await client.one(
        Queries.editablePermissions(sqlFragment`
          SELECT users.* FROM jasb.users WHERE users.slug = ${userSlug}
        `),
      );
    });
  }

  async setPermissions(
    editorSlug: string,
    sessionId: SecretToken,
    userSlug: string,
    gameSlug: string | undefined,
    manage_games: boolean | undefined,
    manage_permissions: boolean | undefined,
    manage_bets: boolean | undefined,
  ): Promise<Users.EditablePermissions> {
    return await this.inTransaction(async (client) => {
      return await client.one(
        Queries.editablePermissions(sqlFragment`
          SELECT * FROM jasb.set_permissions(
            ${editorSlug},
            ${sessionId.uri},
            ${this.config.auth.sessionLifetime.toString()},
            ${userSlug},
            ${gameSlug ?? null},
            ${manage_games ?? null},
            ${manage_permissions ?? null},
            ${manage_bets ?? null}
          )
        `),
      );
    });
  }

  async garbageCollect(): Promise<readonly string[]> {
    return await this.inTransaction(async (client) => {
      const results = await client.query(
        Queries.accessToken(sqlFragment`
          DELETE FROM
            jasb.sessions
          WHERE
            NOW() >= (started + ${this.config.auth.sessionLifetime.toString()}::INTERVAL)
          RETURNING sessions.*
        `),
      );
      return results.rows.map((row) => row.access_token);
    });
  }

  async avatarCacheGarbageCollection(
    garbageCollectBatchSize: number,
  ): Promise<readonly string[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.avatarMeta(sqlFragment`
          SELECT avatars.*
          FROM 
            jasb.avatars LEFT JOIN 
            jasb.users ON avatars.id = users.avatar
          WHERE avatars.cached AND users.id IS NULL
          LIMIT ${garbageCollectBatchSize}
        `),
      );
      return results.rows.map((row) => row.url);
    });
  }

  async avatarsToCache(
    cacheBatchSize: number,
  ): Promise<readonly AvatarCache.Meta[]> {
    return await this.withClient(async (client) => {
      const results = await client.query(
        Queries.avatarMeta(sqlFragment`
          SELECT avatars.*
          FROM jasb.avatars
          WHERE avatars.cached IS NOT TRUE
          LIMIT ${cacheBatchSize}
        `),
      );
      return results.rows;
    });
  }

  async updateCachedAvatars(
    cached: readonly { oldUrl: string; newUrl: string }[],
  ): Promise<number> {
    const result = await this.inTransaction(
      async (client) =>
        await client.one(
          Queries.count(sqlFragment`
            UPDATE jasb.avatars 
            SET 
              url = cached.new_url,
              cached = TRUE
            FROM ${Slonik.sql.unnest(
              cached.map(({ oldUrl, newUrl }) => [oldUrl, newUrl]),
              ["text", "text"],
            )} AS cached(old_url, new_url) 
            WHERE avatars.cached IS NOT TRUE AND avatars.url = cached.old_url
            RETURNING avatars.id
          `),
        ),
    );
    return result.affected;
  }

  async deleteCachedAvatars(deleted: readonly string[]): Promise<number> {
    const result = await this.inTransaction(
      async (client) =>
        await client.one(
          Queries.count(sqlFragment`
            DELETE FROM jasb.avatars 
            WHERE url = ANY(${Slonik.sql.array(deleted, "text")})
            RETURNING avatars.id
          `),
        ),
    );
    return result.affected;
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
