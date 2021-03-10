import {
  DocumentReference,
  Firestore,
  Timestamp,
} from "@google-cloud/firestore";

import { V0 } from "../v0";
import { V1 } from "../v1";

function slugify(name: string) {
  return name.toLowerCase().split(" ").join("-");
}

const initialAmount = 1000;
const freeBetSize = 100;

export async function version0to1(db: Firestore): Promise<number> {
  return db.runTransaction(async (transaction) => {
    const userBets = new Map<string, DocumentReference[]>();

    function mapOldOption(
      newRef: DocumentReference,
      oldOption: V0.Option
    ): { id: string; option: V1.Option } {
      const stakes: Record<string, V1.Stake> = {};
      for (const userId of oldOption.votes) {
        stakes[userId] = { amount: freeBetSize, at: Timestamp.now() };
        const entry = userBets.get(userId) ?? [];
        entry.push(newRef);
        userBets.set(userId, entry);
      }
      return { id: oldOption.id, option: { name: oldOption.name, stakes } };
    }

    const toSet = new Map<DocumentReference, unknown>();
    const toDelete: DocumentReference[] = [];

    const bets = await transaction.get(db.collection("bets"));
    for (const betDoc of bets.docs) {
      const oldBet = betDoc.data() as V0.Bet;
      const newRef = oldBet.game.collection("bets").doc(slugify(oldBet.name));
      const progress = oldBet.progress;

      const bet: V1.Bet = {
        name: oldBet.name,
        description: oldBet.description,
        spoiler: oldBet.spoiler,

        progress:
          progress.state === "Voting"
            ? { state: "Voting", locksWhen: "the game is started" }
            : progress.state === "Complete"
            ? { state: "Complete", winner: progress.winner }
            : { state: "Locked" },

        options: oldBet.options.map((o) => mapOldOption(newRef, o)),
      };
      toDelete.push(betDoc.ref);
      toSet.set(newRef, bet);
    }

    const users = await transaction.get(db.collection("users"));
    for (const userDoc of users.docs) {
      const oldUser = userDoc.data() as V0.User;
      const existing = userBets.get(userDoc.id) ?? [];
      const freeBets = existing.length * freeBetSize;
      const user: V1.User = {
        accessToken: oldUser.accessToken,
        refreshToken: oldUser.refreshToken,

        name: oldUser.name,
        discriminator: oldUser.discriminator,
        avatar: oldUser.avatar,

        balance: initialAmount,
        betValue: freeBets,
        netWorth: initialAmount + freeBets,

        stakesIn: existing,

        created: Timestamp.now(),
        admin: oldUser.admin ?? false,
      };
      toSet.set(userDoc.ref, user);
    }

    const games = await transaction.get(db.collection("games"));
    for (const gameDoc of games.docs) {
      const oldGame = gameDoc.data() as V0.Game;
      const game: V1.Game = {
        name: oldGame.name,
        cover: oldGame.igdbImageId
          ? `https://images.igdb.com/igdb/image/upload/t_cover_small/${oldGame.igdbImageId}.jpg`
          : "",

        bets: oldGame.bets,

        progress: oldGame.future
          ? { state: "Future" }
          : oldGame.finish
          ? {
              state: "Finished",
              start: oldGame.start ?? Timestamp.now(),
              finish: oldGame.finish,
            }
          : { state: "Current", start: oldGame.start ?? Timestamp.now() },
      };
      toSet.set(gameDoc.ref, game);
    }

    for (const ref of toDelete) {
      await transaction.delete(ref);
    }

    for (const [ref, data] of toSet.entries()) {
      await transaction.set(ref, data);
    }

    return 1;
  });
}
