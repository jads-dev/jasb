import * as Schema from "io-ts";

import type { Internal } from "../internal.js";
import { Expect } from "../util/expect.js";
import { Bets } from "./bets.js";
import { Games } from "./games.js";
import { Users } from "./users.js";

const idAndName = <T extends Schema.Mixed>(id: T) =>
  Schema.tuple([id, Schema.string]);

/**
 * A feed event about a new bet being made.
 */
const NewBet = Schema.readonly(
  Schema.strict({
    type: Schema.literal("NewBet"),
    game: idAndName(Games.Id),
    bet: idAndName(Bets.Id),
    spoiler: Schema.boolean,
  }),
);
type NewBet = Schema.TypeOf<typeof NewBet>;

/**
 * A feed event about a bet being completed.
 */
const BetComplete = Schema.readonly(
  Schema.strict({
    type: Schema.literal("BetComplete"),
    game: idAndName(Games.Id),
    bet: idAndName(Bets.Id),
    spoiler: Schema.boolean,
    winners: Schema.readonlyArray(idAndName(Bets.Options.Id)),
    highlighted: Schema.readonly(
      Schema.strict({
        winners: Schema.readonlyArray(Schema.tuple([Users.Id, Users.Summary])),
        amount: Schema.Int,
      }),
    ),
    totalReturn: Schema.Int,
    winningBets: Schema.Int,
  }),
);
type BetComplete = Schema.TypeOf<typeof BetComplete>;

/**
 * A feed event about a notably large stake being placed.
 */
const NotableStake = Schema.readonly(
  Schema.strict({
    type: Schema.literal("NotableStake"),
    game: idAndName(Games.Id),
    bet: idAndName(Bets.Id),
    spoiler: Schema.boolean,
    option: idAndName(Bets.Options.Id),
    user: Schema.tuple([Users.Id, Users.Summary]),
    message: Schema.string,
    stake: Schema.Int,
  }),
);
type NotableStake = Schema.TypeOf<typeof NotableStake>;

/**
 * An event in the feed.
 */
export const Event = Schema.union([NewBet, BetComplete, NotableStake]);
export type Event = Schema.TypeOf<typeof Event>;

export const unknownEvent = Expect.exhaustive(
  "feed event",
  (i: Internal.Feed.Event) => i.type,
);

const idAndNameFromInternal = <Id extends string>(internal: {
  slug: string;
  name: string;
}): [Id, string] => [internal.slug as Id, internal.name];

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
          winners: event.highlighted.winners.map(Users.summaryFromInternal),
          amount: event.highlighted.amount as Schema.Int,
        },
        totalReturn: event.totalReturn as Schema.Int,
        winningBets: event.winningStakes as Schema.Int,
      };
    case "NotableStake":
      return {
        type: "NotableStake",
        game: idAndNameFromInternal(event.game),
        bet: idAndNameFromInternal(event.bet),
        spoiler: event.spoiler,
        option: idAndNameFromInternal(event.option),
        user: Users.summaryFromInternal(event.user),
        message: event.message,
        stake: event.stake as Schema.Int,
      };
    default:
      return unknownEvent(event);
  }
};

export * as Feed from "./feed.js";
