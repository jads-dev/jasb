import { default as Express } from "express";
import { default as asyncHandler } from "express-async-handler";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";

import { Bets, Editor, Feed, Games } from "../../public";
import { Options } from "../../public/bets/options";
import { Validation } from "../../util/validation";
import { WebError } from "../errors";
import { Server } from "../model";
import { requireSession } from "./auth";

const StakeBody = Schema.intersection([
  Schema.strict({
    amount: Schema.Int,
  }),
  Schema.partial({
    message: Schema.string,
  }),
]);
type StakeBody = Schema.TypeOf<typeof StakeBody>;

const BetBody = {
  name: Schema.string,
  description: Schema.string,
  spoiler: Schema.boolean,
  locksWhen: Schema.string,
};
const CreateBetBody = Schema.intersection([
  Schema.strict(BetBody),
  Schema.strict({
    addOptions: Schema.array(
      Schema.strict({
        id: Options.Id,
        name: Schema.string,
        image: Schema.union([Schema.string, Schema.null]),
      })
    ),
  }),
]);
const EditBetBody = Schema.intersection([
  Schema.strict({ version: Schema.Int }),
  Schema.partial(BetBody),
  Schema.partial({
    removeOptions: Schema.array(Schema.string),
    editOptions: Schema.array(
      Schema.intersection([
        Schema.strict({
          id: Options.Id,
          version: Schema.Int,
        }),
        Schema.partial({
          name: Schema.string,
          image: Schema.union([Schema.string, Schema.null]),
          order: Schema.Int,
        }),
      ])
    ),
    addOptions: Schema.array(
      Schema.strict({
        id: Options.Id,
        name: Schema.string,
        image: Schema.union([Schema.string, Schema.null]),
        order: Schema.Int,
      })
    ),
  }),
]);
const CancelBetBody = Schema.strict({
  version: Schema.Int,
  reason: Schema.string,
});
const CompleteBetBody = Schema.strict({
  version: Schema.Int,
  winners: Schema.array(Options.Id),
});
const ModifyLockStateBody = Schema.strict({
  version: Schema.Int,
});

export const betsApi = (server: Server.State): Express.Router => {
  const router = Express.Router({ mergeParams: true });

  // Get Bet.
  router.get(
    "/",
    asyncHandler(async (request, response) => {
      const game = await server.store.getGame(request.params.gameId);
      if (game === undefined) {
        throw new WebError(StatusCodes.NOT_FOUND, "Game not found.");
      }
      const bet = await server.store.getBet(
        request.params.gameId,
        request.params.betId
      );
      if (bet === undefined) {
        throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
      }
      const result: { game: Games.Game; bet: Bets.Bet } = {
        game: Games.fromInternal(game).game,
        bet: Bets.fromInternal(bet).bet,
      };
      response.json(result);
    })
  );

  router.get(
    "/edit",
    asyncHandler(async (request, response) => {
      const bet = await server.store.getBet(
        request.params.gameId,
        request.params.betId
      );
      if (bet === undefined) {
        throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
      }
      const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
      response.json(result);
    })
  );

  // Create Bet
  router.put(
    "/",
    asyncHandler(async (request, response) => {
      const sessionCookie = requireSession(request.cookies);
      const gameId = request.params.gameId;
      const betId = request.params.betId;
      const body = Validation.body(CreateBetBody, request.body);
      const bet = await server.store.newBet(
        sessionCookie.user,
        sessionCookie.session,
        gameId,
        betId,
        body.name,
        body.description,
        body.spoiler,
        body.locksWhen,
        body.addOptions
      );
      const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
      response.json(result);
    })
  );

  // Edit Bet
  router.post(
    "/",
    asyncHandler(async (request, response) => {
      const sessionCookie = requireSession(request.cookies);
      const gameId = request.params.gameId;
      const betId = request.params.betId;
      const body = Validation.body(EditBetBody, request.body);
      const bet = await server.store.editBet(
        sessionCookie.user,
        sessionCookie.session,
        gameId,
        betId,
        body.version,
        body.name,
        body.description,
        body.spoiler,
        body.locksWhen,
        body.removeOptions,
        body.editOptions,
        body.addOptions
      );
      if (bet === undefined) {
        throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
      }
      const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
      response.json(result);
    })
  );

  // Complete Bet
  router.post(
    "/complete",
    asyncHandler(async (request, response) => {
      const sessionCookie = requireSession(request.cookies);
      const gameId = request.params.gameId;
      const body = Validation.body(CompleteBetBody, request.body);
      const bet = await server.store.completeBet(
        sessionCookie.user,
        sessionCookie.session,
        gameId,
        request.params.betId,
        body.version,
        body.winners
      );
      if (bet === undefined) {
        throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
      }
      const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
      response.json(result);
    })
  );

  // Lock Bet
  router.post(
    "/lock",
    asyncHandler(async (request, response) => {
      const sessionCookie = requireSession(request.cookies);
      const gameId = request.params.gameId;
      const body = Validation.body(ModifyLockStateBody, request.body);
      const bet = await server.store.setBetLocked(
        sessionCookie.user,
        sessionCookie.session,
        gameId,
        request.params.betId,
        body.version,
        true
      );
      if (bet === undefined) {
        throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
      }
      const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
      response.json(result);
    })
  );

  // Unlock Bet
  router.post(
    "/unlock",
    asyncHandler(async (request, response) => {
      const sessionCookie = requireSession(request.cookies);
      const gameId = request.params.gameId;
      const body = Validation.body(ModifyLockStateBody, request.body);
      const bet = await server.store.setBetLocked(
        sessionCookie.user,
        sessionCookie.session,
        gameId,
        request.params.betId,
        body.version,
        false
      );
      if (bet === undefined) {
        throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
      }
      const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
      response.json(result);
    })
  );

  // Cancel Bet
  router.post(
    "/cancel",
    asyncHandler(async (request, response) => {
      const sessionCookie = requireSession(request.cookies);
      const gameId = request.params.gameId;
      const body = Validation.body(CancelBetBody, request.body);
      const bet = await server.store.cancelBet(
        sessionCookie.user,
        sessionCookie.session,
        gameId,
        request.params.betId,
        body.version,
        body.reason
      );
      if (bet === undefined) {
        throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
      }
      const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
      response.json(result);
    })
  );

  // Get Bet Feed
  router.get(
    "/feed",
    asyncHandler(async (request, response) => {
      const gameId = request.params.gameId;
      const betId = request.params.betId;
      const feed = await server.store.getBetFeed(gameId, betId);
      const result: Feed.Event[] = feed.map(Feed.fromInternal);
      response.json(result);
    })
  );

  function validateStakeBody(body: unknown): StakeBody {
    const stakeBody = Validation.body(StakeBody, body);
    if (stakeBody.amount === undefined) {
      throw new WebError(StatusCodes.BAD_REQUEST, "No amount given.");
    }
    if (stakeBody.message !== undefined) {
      if (stakeBody.amount < server.config.rules.notableStake) {
        throw new WebError(
          StatusCodes.BAD_REQUEST,
          "Not allowed to give a message without a notable bet amount."
        );
      }
      if (stakeBody.message.length > 200) {
        throw new WebError(
          StatusCodes.BAD_REQUEST,
          "Invalid message given (too long)."
        );
      }
    }
    if (stakeBody.amount < 0) {
      throw new WebError(
        StatusCodes.BAD_REQUEST,
        "Can't bet a negative amount."
      );
    }
    return stakeBody;
  }

  // Place Stake.
  router.put(
    "/options/:optionId/stake",
    asyncHandler(async (request, response) => {
      const sessionCookie = requireSession(request.cookies);
      const { amount, message } = validateStakeBody(request.body);
      const new_balance = await server.store.newStake(
        sessionCookie.user,
        sessionCookie.session,
        request.params.gameId,
        request.params.betId,
        request.params.optionId,
        amount,
        message ?? null
      );
      response.json(new_balance);
    })
  );

  // Edit Stake.
  router.post(
    "/options/:optionId/stake",
    asyncHandler(async (request, response) => {
      const sessionCookie = requireSession(request.cookies);
      const { amount, message } = validateStakeBody(request.body);
      const new_balance = await server.store.changeStake(
        sessionCookie.user,
        sessionCookie.session,
        request.params.gameId,
        request.params.betId,
        request.params.optionId,
        amount,
        message ?? null
      );
      response.json(new_balance);
    })
  );

  // Withdraw Stake.
  router.delete(
    "/options/:optionId/stake",
    asyncHandler(async (request, response) => {
      const sessionCookie = requireSession(request.cookies);
      const new_balance = await server.store.withdrawStake(
        sessionCookie.user,
        sessionCookie.session,
        request.params.gameId,
        request.params.betId,
        request.params.optionId
      );
      response.json(new_balance);
    })
  );

  return router;
};
