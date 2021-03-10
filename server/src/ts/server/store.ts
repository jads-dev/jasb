import {
  default as Firestore,
  DocumentReference,
  FieldPath,
  Timestamp,
  Transaction,
} from "@google-cloud/firestore";
import { StatusCodes } from "http-status-codes";
import { default as Winston } from "winston";

import { Discord } from "../external";
import {
  Bet,
  Bets,
  EventLog,
  Game,
  Notification,
  Notifications,
  User,
} from "../internal";
import { Config } from "./config";
import { WebError } from "./errors";
import { migrateIfNeeded } from "./store/migrate";

export class Store {
  config: Config.Server;
  db: Firestore.Firestore;

  private constructor(config: Config.Server) {
    this.config = config;
    this.db = new Firestore.Firestore({
      projectId: config.store.projectId,
    });
  }

  static async load(
    logger: Winston.Logger,
    config: Config.Server
  ): Promise<Store> {
    const store = new Store(config);
    await migrateIfNeeded(logger, store.db);
    return store;
  }

  async commitStake(
    userId: string,
    gameId: string,
    betId: string,
    optionId: string,
    desiredAmount: number
  ): Promise<{ bet: Bet; user: User }> {
    if (desiredAmount < 0) {
      throw new WebError(
        StatusCodes.BAD_REQUEST,
        "Can't bet negative amounts."
      );
    }

    const userRef = this.db.collection("users").doc(userId);
    const betRef = this.db
      .collection("games")
      .doc(gameId)
      .collection("bets")
      .doc(betId);

    return await this.db.runTransaction(async (transaction) => {
      const [betResult, userResult] = await Promise.all([
        transaction.get(betRef),
        transaction.get(userRef),
      ]);
      const bet = betResult.data() as Bet | undefined;
      const user = userResult.data() as User | undefined;
      if (user === undefined) {
        throw new WebError(
          StatusCodes.INTERNAL_SERVER_ERROR,
          "User not found."
        );
      }
      if (bet === undefined) {
        throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
      }
      if (bet.progress.state !== "Voting") {
        throw new WebError(StatusCodes.BAD_REQUEST, "Can't vote any more.");
      }
      const maybeOption = bet.options.find((o) => o.id === optionId);
      if (maybeOption === undefined) {
        throw new WebError(StatusCodes.NOT_FOUND, "Option not found.");
      }
      const { option } = maybeOption;
      const existingStake = option.stakes[userId];
      const existingAmount = existingStake?.amount ?? 0;
      if (existingStake !== undefined) {
        if (desiredAmount < 1) {
          delete option.stakes[userId];
        } else {
          existingStake.amount = desiredAmount;
          existingStake.at = Timestamp.now();
        }
      } else {
        if (desiredAmount < 1) {
          return { bet, user };
        } else {
          option.stakes[userId] = {
            amount: desiredAmount,
            at: Timestamp.now(),
          };
        }
      }
      const change = desiredAmount - existingAmount;
      user.betValue += change;
      user.balance -= change;
      if (user.balance < 0) {
        if (desiredAmount > 100) {
          throw new WebError(
            StatusCodes.BAD_REQUEST,
            "Can't stake more than 100 if it results in a negative balance"
          );
        }

        if (
          bet.options.some(
            ({ id, option }) =>
              id !== optionId && option.stakes[userId] !== undefined
          )
        ) {
          throw new WebError(
            StatusCodes.BAD_REQUEST,
            "Can't vote for another option if it results in a negative balance."
          );
        }
      }
      user.stakesIn = user.stakesIn.filter((b) => !b.isEqual(betRef));
      if (bet.options.some((o) => o.option.stakes[userId] !== undefined)) {
        user.stakesIn.push(betRef);
      }
      const stake = option.stakes[userId];
      this.newLogEntry(
        transaction,
        userId,
        stake !== undefined
          ? {
              event: "StakeCommitted",
              bet: betRef,
              option: optionId,
              stake,
            }
          : {
              event: "StakeWithdrawn",
              bet: betRef,
              option: optionId,
              amount: existingAmount,
            }
      );
      transaction.set(userRef, user);
      transaction.set(betRef, bet);
      return { bet, user };
    });
  }

  async bankrupt(userId: string): Promise<void> {
    const userDoc = this.db.collection("users").doc(userId);
    const initialBalance = this.config.rules.initialBalance;
    await this.db.runTransaction(async (transaction) => {
      const user = (await userDoc.get()).data() as User;
      for (const betRef of user.stakesIn) {
        const bet = (await betRef.get()).data() as Bet;
        for (const { option } of bet.options) {
          delete option.stakes[userId];
        }
        transaction.set(betRef, bet);
      }
      this.newLogEntry(transaction, userId, {
        event: "Bankruptcy",
        balance: initialBalance,
      });
      transaction.update(userDoc, {
        balance: initialBalance,
        betValue: 0,
        netWorth: initialBalance,
        stakesIn: [],
      });
    });
  }

  async getOrCreateUser(
    discordToken: Discord.Token,
    discordUser: Discord.User
  ): Promise<User> {
    const { id } = discordUser;
    const { initialBalance } = this.config.rules;
    const userDoc = this.db.collection("users").doc(id);
    return await this.db.runTransaction(async (transaction) => {
      const userData = await transaction.get(userDoc);
      const user = userData.data() as User;
      if (user === undefined) {
        const newUser: User = {
          accessToken: discordToken.access_token,
          refreshToken: discordToken.refresh_token,

          name: discordUser.username,
          discriminator: discordUser.discriminator,
          avatar: discordUser.avatar || undefined,

          balance: initialBalance,
          betValue: 0,
          netWorth: initialBalance,

          stakesIn: [],

          created: Timestamp.now(),
          admin: false,
        };
        this.newNotification(transaction, id, {
          type: "Gifted",
          amount: initialBalance,
          reason: "AccountCreated",
        });
        this.newLogEntry(transaction, id, {
          event: "CreateAccount",
          balance: initialBalance,
        });
        transaction.set(userDoc, newUser);
        return newUser;
      } else {
        return user;
      }
    });
  }

  async getUser(id: string): Promise<User | undefined> {
    const userDoc = await this.db.collection("users").doc(id).get();
    return userDoc.data() as User | undefined;
  }

  async *getUsers(): AsyncIterable<{ id: string; user: User }> {
    const users = this.db.collection("users");
    const leaderboard = await users
      .where("netWorth", ">", this.config.rules.initialBalance)
      .orderBy("netWorth", "desc")
      .limit(100)
      .get();
    for (const doc of leaderboard.docs) {
      const user = doc.data() as User;
      yield {
        id: doc.id,
        user,
      };
    }
  }

  async getGame(id: string): Promise<Game | undefined> {
    const doc = await this.db.collection("games").doc(id).get();
    return doc.data() as Game | undefined;
  }

  async *getGames(
    subset?: "Future" | "Started" | "Finished"
  ): AsyncIterable<{ id: string; game: Game }> {
    const games = this.db.collection("games");
    const gamesSubset =
      subset !== undefined
        ? games.where("progress.status", "==", subset)
        : games;
    const leaderboard = await gamesSubset.limit(100).get();
    for (const doc of leaderboard.docs) {
      yield { id: doc.id, game: doc.data() as Game };
    }
  }

  async *getBets(gameId: string): AsyncIterable<{ id: string; bet: Bet }> {
    const betsCollection = await this.db
      .collection("games")
      .doc(gameId)
      .collection("bets")
      .where(new FieldPath("progress", "state"), "!=", "Suggestion")
      .get();

    for (const bet of betsCollection.docs) {
      yield { id: bet.id, bet: bet.data() as Bet };
    }
  }

  async *getSuggestions(
    gameId: string,
    by?: string
  ): AsyncIterable<{ id: string; bet: Bet & { progress: Bets.Suggestion } }> {
    const betsCollection = this.db
      .collection("games")
      .doc(gameId)
      .collection("bets")
      .where(new FieldPath("progress", "state"), "==", "Suggestion");

    const byUser =
      by !== undefined
        ? betsCollection.where(
            new FieldPath("progress", "state", "by"),
            "==",
            by
          )
        : betsCollection;

    const bets = await byUser.get();

    for (const bet of bets.docs) {
      yield {
        id: bet.id,
        bet: bet.data() as Bet & { progress: Bets.Suggestion },
      };
    }
  }

  async getBet(gameId: string, betId: string): Promise<Bet | undefined> {
    const betDoc = await this.db
      .collection("games")
      .doc(gameId)
      .collection("bets")
      .doc(betId)
      .get();
    return betDoc.data() as Bet | undefined;
  }

  async setGame(gameId: string, game: Game): Promise<boolean> {
    const gameRef = this.db.collection("games").doc(gameId);
    return await this.db.runTransaction(async (transaction) => {
      const existingDoc = await transaction.get(gameRef);
      const existing = existingDoc.data() as Game | undefined;
      if (existing !== undefined) {
        game.bets = existing.bets;
      }
      transaction.set(gameRef, game);
      return existing === undefined;
    });
  }

  async setBet(gameId: string, betId: string, bet: Bet): Promise<boolean> {
    const gameRef = this.db.collection("games").doc(gameId);
    const betRef = gameRef.collection("bets").doc(betId);
    return await this.db.runTransaction(async (transaction) => {
      const gameDoc = await transaction.get(gameRef);
      const game = gameDoc.data() as Game | undefined;
      if (game === undefined) {
        throw new WebError(StatusCodes.NOT_FOUND, "No such game.");
      }
      const betDoc = await transaction.get(betRef);
      const existing = betDoc.data() as Bet | undefined;
      if (existing !== undefined) {
        const hasStakeStill = new Set<string>();
        const notifications: {
          user: string;
          message: Notifications.Message;
        }[] = [];
        const events: { user: string; event: EventLog.Event }[] = [];
        const userChange = new Map<
          string,
          { balance: number; betValue: number }
        >();
        for (const { id, option } of existing.options) {
          const replacementOption = bet.options.find((o) => o.id === id);
          if (replacementOption !== undefined) {
            replacementOption.option.stakes = option.stakes;
            for (const user of Object.keys(option.stakes)) {
              hasStakeStill.add(user);
            }
          } else {
            for (const [user, stake] of Object.entries(option.stakes)) {
              const change = userChange.get(user) ?? {
                balance: 0,
                betValue: 0,
              };
              change.betValue -= stake.amount;
              change.balance += stake.amount;
              const message: Notifications.Refunded = {
                type: "Refunded",
                gameId,
                gameName: game.name,
                betId,
                betName: bet.name,
                optionId: id,
                optionName: option.name,
                reason: "OptionRemoved",
                amount: stake.amount,
              };
              notifications.push({ user, message });
              const event: EventLog.Refund = {
                event: "Refund",
                bet: betRef,
                option: id,
                optionName: option.name,
                stake,
              };
              events.push({
                user,
                event,
              });
              userChange.set(user, change);
            }
          }
        }

        const completed =
          existing.progress.state !== "Complete" &&
          bet.progress.state === "Complete";

        const cancelled =
          existing.progress.state !== "Cancelled" &&
          bet.progress.state === "Cancelled";

        if (completed || cancelled) {
          const winner =
            bet.progress.state === "Complete" ? bet.progress.winner : undefined;
          hasStakeStill.clear();

          const total = bet.options.reduce(
            (total, { option }) =>
              total +
              Object.values(option.stakes).reduce(
                (subtotal, { amount }) => subtotal + amount,
                0
              ),
            0
          );

          for (const { id, option } of bet.options) {
            const betDetails = {
              gameId,
              gameName: game.name,
              betId,
              betName: bet.name,
              optionId: id,
              optionName: option.name,
            };
            if (id === winner) {
              const betOnThis = Object.values(option.stakes).reduce(
                (subtotal, { amount }) => subtotal + amount,
                0
              );
              const amountWonPerBet = betOnThis > 0 ? total / betOnThis : 0;
              for (const [user, stake] of Object.entries(option.stakes)) {
                const change = userChange.get(user) ?? {
                  balance: 0,
                  betValue: 0,
                };
                const winnings = Math.floor(amountWonPerBet * stake.amount);
                change.balance += winnings;
                notifications.push({
                  user,
                  message: {
                    type: "BetFinished",
                    ...betDetails,
                    result: "Win",
                    amount: winnings,
                  },
                });
                events.push({
                  user,
                  event: {
                    event: "Payout",
                    bet: betRef,
                    option: id,
                    stake,
                    winnings,
                  },
                });
                userChange.set(user, change);
              }
            }
            for (const [user, stake] of Object.entries(option.stakes)) {
              const change = userChange.get(user) ?? {
                balance: 0,
                betValue: 0,
              };
              if (id !== winner) {
                if (cancelled) {
                  change.balance += stake.amount;
                  change.betValue -= stake.amount;
                  notifications.push({
                    user,
                    message: {
                      type: "Refunded",
                      ...betDetails,
                      reason: "BetCancelled",
                      amount: stake.amount,
                    },
                  });
                  events.push({
                    user,
                    event: {
                      event: "Refund",
                      bet: betRef,
                      option: id,
                      optionName: option.name,
                      stake,
                    },
                  });
                } else {
                  change.betValue -= stake.amount;
                  notifications.push({
                    user,
                    message: {
                      type: "BetFinished",
                      ...betDetails,
                      result: "Loss",
                      amount: stake.amount,
                    },
                  });
                  events.push({
                    user,
                    event: {
                      event: "Loss",
                      bet: betRef,
                      option: id,
                      stake,
                    },
                  });
                }
              }
              userChange.set(user, change);
            }
          }
        }

        const updates = new Map<DocumentReference, Record<string, unknown>>();
        for (const [userId, change] of userChange.entries()) {
          const userRef = this.db.collection("users").doc(userId);
          const userDoc = await userRef.get();
          const user = userDoc.data() as User;
          const balance = Math.floor(user.balance + change.balance);
          const betValue = Math.floor(
            Math.max(user.betValue + change.betValue, 0)
          );
          updates.set(userRef, {
            balance,
            betValue,
            netWorth: balance + betValue,

            ...(!hasStakeStill.has(userId)
              ? {
                  stakesIn: user.stakesIn.filter((ref) => !ref.isEqual(betRef)),
                }
              : {}),
          });
        }
        for (const [ref, doc] of updates.entries()) {
          transaction.update(ref, doc);
        }
        for (const { user, message } of notifications) {
          this.newNotification(transaction, user, message);
        }
        for (const { user, event } of events) {
          this.newLogEntry(transaction, user, event);
        }
      } else {
        transaction.update(gameRef, { bets: game.bets + 1 });
      }
      transaction.set(betRef, bet);
      return existing === undefined;
    });
  }

  async getNotifications(
    userId: string
  ): Promise<Notifications.Notification[]> {
    const notificationsRef = this.db
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .orderBy("at", "desc");
    const notifications = await notificationsRef.get();
    const result: Notifications.Notification[] = [];
    for (const notification of notifications.docs) {
      result.push(notification.data() as Notifications.Notification);
    }
    return result;
  }

  async clearNotifications(userId: string): Promise<void> {
    const notificationsRef = this.db
      .collection("users")
      .doc(userId)
      .collection("notifications");
    const notifications = await notificationsRef.get();
    for (const notification of notifications.docs) {
      await notification.ref.delete();
    }
  }

  private newNotification(
    transaction: Transaction,
    forUser: string,
    message: Notifications.Message
  ): void {
    const newEntry = this.db
      .collection("users")
      .doc(forUser)
      .collection("notifications")
      .doc();
    const notification: Notification = {
      message,
      at: Timestamp.now(),
    };
    transaction.set(newEntry, notification);
  }

  private newLogEntry(
    transaction: Transaction,
    forUser: string,
    event: EventLog.Event
  ): void {
    const newEntry = this.db
      .collection("users")
      .doc(forUser)
      .collection("events")
      .doc();
    const entry: EventLog.Entry = {
      event,
      at: Timestamp.now(),
    };
    transaction.set(newEntry, entry);
  }
}
