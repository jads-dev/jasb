/* eslint-disable @typescript-eslint/explicit-module-boundary-types */
import { default as Firestore } from "@google-cloud/firestore";
import * as Joda from "@js-joda/core";

import { Config } from "../../server/config";
import {
  Bet,
  Bets,
  EventLog,
  Feed,
  Game,
  Games,
  Notification,
  Option,
  User,
} from "../../server/store/v4";

/**
 * A loader for data from a firestore database.
 */
export class FirestoreLoader {
  config: Config.Server;
  db: Firestore.Firestore;

  public constructor(config: Config.Server) {
    this.config = config;
    this.db = new Firestore.Firestore({
      projectId: config.store.projectId,
    });
  }

  private static toIso(date: Firestore.Timestamp): string {
    return Joda.ZonedDateTime.ofInstant(
      Joda.Instant.ofEpochMilli(date.toMillis()),
      Joda.ZoneOffset.UTC
    ).toString();
  }

  private static toIsoOrUndefined(
    date?: Firestore.Timestamp
  ): string | undefined {
    return date == undefined ? undefined : FirestoreLoader.toIso(date);
  }

  async users() {
    const usersCollection = this.db.collection("users");
    const users = await usersCollection.get();
    const userParams = users.docs.map((userDoc) => {
      const user = userDoc.data() as User;
      return [
        userDoc.id,
        user.name,
        user.discriminator,
        user.avatar ?? null,
        FirestoreLoader.toIso(user.created),
        user.admin ?? false,
        user.balance,
      ];
    });
    const moderatorParams = users.docs.flatMap((userDoc) => {
      const user = userDoc.data() as User;
      return (user.mod ?? []).map((game) => [userDoc.id, game, true]);
    });
    return { users: userParams, moderators: moderatorParams };
  }

  async games() {
    const gamesCollection = this.db.collection("games");
    const games = await gamesCollection.get();
    return {
      games: games.docs.map((gameDoc) => {
        const game = gameDoc.data() as Game;
        return [
          gameDoc.id,
          game.cover,
          game.name,
          "",
          FirestoreLoader.toIsoOrUndefined(
            (game.progress as Games.Finished)?.start
          ) ?? null,
          FirestoreLoader.toIsoOrUndefined(
            (game.progress as Games.Finished)?.finish
          ) ?? null,
        ];
      }),
    };
  }

  async logs() {
    const logsCollection = this.db.collectionGroup("events");
    const logs = await logsCollection.get();
    return {
      logs: logs.docs.map((entryDoc) => {
        const entry = entryDoc.data() as EventLog.Entry;
        return [
          entryDoc.ref.parent.parent!.id,
          FirestoreLoader.toIso(entry.at),
          JSON.stringify(entry.event),
        ];
      }),
    };
  }

  async notifications() {
    const notificationsCollection = this.db.collectionGroup("notifications");
    const notifications = await notificationsCollection.get();
    return {
      notifications: notifications.docs.map((notificationDoc) => {
        const notification = notificationDoc.data() as Notification;
        return [
          notificationDoc.ref.parent.parent!.id,
          FirestoreLoader.toIso(notification.at),
          JSON.stringify(notification.message),
        ];
      }),
    };
  }

  async bets() {
    const feedItemCollection = this.db.collectionGroup("feed");
    const feedItems = await feedItemCollection.get();
    const stakeMessages = new Map<string, string>();

    for (const feedItemDoc of feedItems.docs) {
      const feedItem = feedItemDoc.data() as Feed.Item;
      if (feedItem.event.type === "NotableStake") {
        const stake = feedItem.event as Feed.NotableStake;
        if (stake.message !== undefined) {
          stakeMessages.set(
            `${stake.game.id}/${stake.bet.id}/${stake.option.id}/${stake.user.id}`,
            stake.message
          );
        }
      }
    }

    const betsCollection = this.db.collectionGroup("bets");
    const bets = await betsCollection.get();
    const relevant = bets.docs
      .map((betDoc) => {
        const bet = betDoc.data() as Bet;
        return { game: betDoc.ref.parent.parent!.id, id: betDoc.id, bet };
      })
      .filter(({ bet }) => bet.progress.state !== "Suggestion");
    const betsParams = relevant.map(({ game, id, bet }) => {
      return [
        game,
        id,
        bet.name,
        bet.description,
        bet.spoiler,
        (bet.progress as Bets.Voting)?.locksWhen ?? "",
        bet.progress.state,
        FirestoreLoader.toIso(bet.created),
        bet.progress.state === "Complete" || bet.progress.state === "Cancelled"
          ? FirestoreLoader.toIso(bet.updated ?? bet.created)
          : null,
        bet.progress.state === "Cancelled"
          ? bet.progress.reason ?? "Cancelled"
          : null,
        bet.author ?? "132972952311431168",
      ];
    });
    const optionsParams = relevant.flatMap(({ game, id, bet }) => [
      ...FirestoreLoader.options(game, id, bet),
    ]);
    const stakesParams = relevant.flatMap(({ game, id, bet }) =>
      bet.options.flatMap((option) => [
        ...FirestoreLoader.stakes(
          game,
          id,
          option.id,
          option.option,
          stakeMessages
        ),
      ])
    );
    return {
      bets: betsParams,
      options: optionsParams,
      stakes: stakesParams,
    };
  }

  private static *options(gameId: string, betId: string, bet: Bet) {
    const winnersOrWinner = (bet.progress as Bets.Complete)?.winner ?? [];
    const winners = Array.isArray(winnersOrWinner)
      ? winnersOrWinner
      : [winnersOrWinner];

    for (const [index, { id, option }] of bet.options.entries()) {
      yield [
        gameId,
        betId,
        id,
        option.name,
        option.image ?? null,
        winners.includes(id),
        index,
      ];
    }
  }

  private static *stakes(
    gameId: string,
    betId: string,
    optionId: string,
    option: Option,
    stakeMessages: Map<string, string>
  ) {
    for (const [owner, stake] of Object.entries(option.stakes)) {
      yield [
        gameId,
        betId,
        optionId,
        owner,
        FirestoreLoader.toIso(stake.at),
        stake.amount,
        stakeMessages.get(`${gameId}/${betId}/${optionId}/${owner}`) ?? null,
      ];
    }
  }
}
