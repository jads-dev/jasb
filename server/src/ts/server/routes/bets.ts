import { default as Router } from "@koa/router";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";
import { koaBody as Body } from "koa-body";

import { Bets, Editor, Feed, Games } from "../../public.js";
import { Options } from "../../public/bets/options.js";
import { Validation } from "../../util/validation.js";
import { WebError } from "../errors.js";
import type { Server } from "../model.js";
import { requireSession } from "./auth.js";

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
      }),
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
      ]),
    ),
    addOptions: Schema.array(
      Schema.strict({
        id: Options.Id,
        name: Schema.string,
        image: Schema.union([Schema.string, Schema.null]),
        order: Schema.Int,
      }),
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
const RevertBody = Schema.strict({
  version: Schema.Int,
});

export const betsApi = (server: Server.State): Router => {
  const router = new Router();

  // Get Bet.
  router.get("/", async (ctx) => {
    const gameId = ctx.params["gameId"] ?? "";
    const betId = ctx.params["betId"] ?? "";
    const game = await server.store.getGame(gameId);
    if (game === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Game not found.");
    }
    const bet = await server.store.getBet(gameId, betId);
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    const result: { game: Games.Game; bet: Bets.Bet } = {
      game: Games.fromInternal(game).game,
      bet: Bets.fromInternal(bet).bet,
    };
    ctx.body = result;
  });

  router.get("/edit", async (ctx) => {
    const bet = await server.store.getBet(
      ctx.params["gameId"] ?? "",
      ctx.params["betId"] ?? "",
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
    ctx.body = result;
  });

  // Create Bet
  router.put("/", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const gameId = ctx.params["gameId"] ?? "";
    const betId = ctx.params["betId"] ?? "";
    const body = Validation.body(CreateBetBody, ctx.request.body);
    const bet = await server.store.newBet(
      sessionCookie.user,
      sessionCookie.session,
      gameId,
      betId,
      body.name,
      body.description,
      body.spoiler,
      body.locksWhen,
      body.addOptions,
    );
    const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
    ctx.body = result;
  });

  // Edit Bet
  router.post("/", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const gameId = ctx.params["gameId"] ?? "";
    const betId = ctx.params["betId"] ?? "";
    const body = Validation.body(EditBetBody, ctx.request.body);
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
      body.addOptions,
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
    ctx.body = result;
  });

  // Complete Bet
  router.post("/complete", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const gameId = ctx.params["gameId"] ?? "";
    const body = Validation.body(CompleteBetBody, ctx.request.body);
    const bet = await server.store.completeBet(
      sessionCookie.user,
      sessionCookie.session,
      gameId,
      ctx.params["betId"] ?? "",
      body.version,
      body.winners,
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
    ctx.body = result;
  });

  // Revert Complete Bet
  router.post("/complete/revert", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const gameId = ctx.params["gameId"] ?? "";
    const body = Validation.body(RevertBody, ctx.request.body);
    const bet = await server.store.revertCompleteBet(
      sessionCookie.user,
      sessionCookie.session,
      gameId,
      ctx.params["betId"] ?? "",
      body.version,
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
    ctx.body = result;
  });

  // Lock Bet
  router.post("/lock", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const gameId = ctx.params["gameId"] ?? "";
    const body = Validation.body(ModifyLockStateBody, ctx.request.body);
    const bet = await server.store.setBetLocked(
      sessionCookie.user,
      sessionCookie.session,
      gameId,
      ctx.params["betId"] ?? "",
      body.version,
      true,
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
    ctx.body = result;
  });

  // Unlock Bet
  router.post("/unlock", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const gameId = ctx.params["gameId"] ?? "";
    const body = Validation.body(ModifyLockStateBody, ctx.request.body);
    const bet = await server.store.setBetLocked(
      sessionCookie.user,
      sessionCookie.session,
      gameId,
      ctx.params["betId"] ?? "",
      body.version,
      false,
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
    ctx.body = result;
  });

  // Cancel Bet
  router.post("/cancel", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const gameId = ctx.params["gameId"] ?? "";
    const body = Validation.body(CancelBetBody, ctx.request.body);
    const bet = await server.store.cancelBet(
      sessionCookie.user,
      sessionCookie.session,
      gameId,
      ctx.params["betId"] ?? "",
      body.version,
      body.reason,
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
    ctx.body = result;
  });

  // Revert Cancel Bet
  router.post("/cancel/revert", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const gameId = ctx.params["gameId"] ?? "";
    const body = Validation.body(RevertBody, ctx.request.body);
    const bet = await server.store.revertCancelBet(
      sessionCookie.user,
      sessionCookie.session,
      gameId,
      ctx.params["betId"] ?? "",
      body.version,
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    const result: Editor.Bets.EditableBet = Editor.Bets.fromInternal(bet);
    ctx.body = result;
  });

  // Get Bet Feed
  router.get("/feed", async (ctx) => {
    const gameId = ctx.params["gameId"] ?? "";
    const betId = ctx.params["betId"] ?? "";
    const feed = await server.store.getBetFeed(gameId, betId);
    const result: Feed.Event[] = feed.map(Feed.fromInternal);
    ctx.body = result;
  });

  function validateStakeBody(body: unknown): StakeBody {
    const stakeBody = Validation.body(StakeBody, body);
    if (stakeBody.amount === undefined) {
      throw new WebError(StatusCodes.BAD_REQUEST, "No amount given.");
    }
    if (stakeBody.message !== undefined) {
      if (stakeBody.amount < server.config.rules.notableStake) {
        throw new WebError(
          StatusCodes.BAD_REQUEST,
          "Not allowed to give a message without a notable bet amount.",
        );
      }
      if (stakeBody.message.length > 200) {
        throw new WebError(
          StatusCodes.BAD_REQUEST,
          "Invalid message given (too long).",
        );
      }
    }
    if (stakeBody.amount < 0) {
      throw new WebError(
        StatusCodes.BAD_REQUEST,
        "Can't bet a negative amount.",
      );
    }
    return stakeBody;
  }

  // Place Stake.
  router.put("/options/:optionId/stake", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const { amount, message } = validateStakeBody(ctx.request.body);
    const new_balance = await server.store.newStake(
      sessionCookie.user,
      sessionCookie.session,
      ctx.params["gameId"] ?? "",
      ctx.params["betId"] ?? "",
      ctx.params["optionId"] ?? "",
      amount,
      message ?? null,
    );
    ctx.body = new_balance;
  });

  // Edit Stake.
  router.post("/options/:optionId/stake", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const { amount, message } = validateStakeBody(ctx.request.body);
    const new_balance = await server.store.changeStake(
      sessionCookie.user,
      sessionCookie.session,
      ctx.params["gameId"] ?? "",
      ctx.params["betId"] ?? "",
      ctx.params["optionId"] ?? "",
      amount,
      message ?? null,
    );
    ctx.body = new_balance;
  });

  // Withdraw Stake.
  router.delete("/options/:optionId/stake", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const new_balance = await server.store.withdrawStake(
      sessionCookie.user,
      sessionCookie.session,
      ctx.params["gameId"] ?? "",
      ctx.params["betId"] ?? "",
      ctx.params["optionId"] ?? "",
    );
    ctx.body = new_balance;
  });

  return router;
};
