import type { Internal } from "../internal.js";
import { Expect } from "../util/expect.js";
import type { Bets } from "./bets.js";
import type { Games } from "./games.js";
import type { Users } from "./users.js";

export interface IdAndName<Id> {
  id: Id;
  name: string;
}

export interface UserInfo {
  id: Users.Id;
  name: string;
  discriminator?: string;
  avatar?: string;
  avatarCache?: string;
}

export interface NewBet {
  type: "NewBet";
  game: IdAndName<Games.Id>;
  bet: IdAndName<Bets.Id>;
  spoiler: boolean;
}

export interface BetComplete {
  type: "BetComplete";
  game: IdAndName<Games.Id>;
  bet: IdAndName<Bets.Id>;
  spoiler: boolean;
  winners: IdAndName<Bets.Options.Id>[];
  highlighted: {
    winners: UserInfo[];
    amount: number;
  };
  totalReturn: number;
  winningBets: number;
}

export interface NotableStake {
  type: "NotableStake";
  game: IdAndName<Games.Id>;
  bet: IdAndName<Bets.Id>;
  spoiler: boolean;
  option: IdAndName<Bets.Options.Id>;
  user: UserInfo;
  message: string;
  stake: number;
}

export type Event = NewBet | BetComplete | NotableStake;

export const unknownEvent = Expect.exhaustive(
  "feed event",
  (i: Internal.Feed.Event) => i.type,
);

export const fromInternal = (internal: Internal.Feed.Item): Event => {
  const event = internal.item;
  switch (event.type) {
    case "NewBet":
      return {
        type: "NewBet",
        game: idAndNameFromInternal(event.game),
        bet: idAndNameFromInternal(event.bet),
        spoiler: event.spoiler,
      };
    case "BetComplete":
      return {
        type: "BetComplete",
        game: idAndNameFromInternal(event.game),
        bet: idAndNameFromInternal(event.bet),
        spoiler: event.spoiler,
        winners: event.winners.map((w) =>
          idAndNameFromInternal<Bets.Options.Id>(w),
        ),
        highlighted: {
          winners: event.highlighted.winners.map(userInfoFromInternal),
          amount: event.highlighted.amount,
        },
        totalReturn: event.totalReturn,
        winningBets: event.winningStakes,
      };
    case "NotableStake":
      return {
        type: "NotableStake",
        game: idAndNameFromInternal(event.game),
        bet: idAndNameFromInternal(event.bet),
        spoiler: event.spoiler,
        option: idAndNameFromInternal(event.option),
        user: userInfoFromInternal(event.user),
        message: event.message,
        stake: event.stake,
      };
    default:
      return unknownEvent(event);
  }
};

const idAndNameFromInternal = <Id extends string>(
  internal: Internal.Feed.IdAndName,
): IdAndName<Id> => ({
  id: internal.id as Id,
  name: internal.name,
});

const userInfoFromInternal = (internal: Internal.Users.Summary): UserInfo => ({
  id: internal.id as Users.Id,
  name: internal.name,
  ...(internal.avatar !== null ? { avatar: internal.avatar } : {}),
  ...(internal.avatar_cache !== null
    ? { avatarCache: internal.avatar_cache }
    : {}),
  ...(internal.discriminator !== null
    ? { discriminator: internal.discriminator }
    : {}),
});
export * as Feed from "./feed.js";
