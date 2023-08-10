import { default as Router } from "@koa/router";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";

import { Bets, Editor, Feed, Games } from "../../public.js";
import { Options } from "../../public/bets/options.js";
import { LockMoments } from "../../public/editor.js";
import { requireUrlParameter, Validation } from "../../util/validation.js";
import { WebError } from "../errors.js";
import type { Server } from "../model.js";
import * as Auth from "./auth.js";
import { body } from "./util.js";

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
  lockMoment: LockMoments.Slug,
};
const CreateBetBody = Schema.intersection([
  Schema.strict(BetBody),
  Schema.strict({
    addOptions: Schema.array(
      Schema.strict({
        id: Options.Slug,
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
    removeOptions: Schema.array(
      Schema.strict({
        id: Options.Slug,
        version: Schema.Int,
      }),
    ),
    editOptions: Schema.array(
      Schema.intersection([
        Schema.strict({
          id: Options.Slug,
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
        id: Options.Slug,
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
  winners: Schema.array(Options.Slug),
});
const ModifyLockStateBody = Schema.strict({
  version: Schema.Int,
});
const RevertBody = Schema.strict({
  version: Schema.Int,
});

export const betsApi = (server: Server.State): Router => {
  const router = new Router();

  const slugs = (ctx: {
    params: Record<string, string>;
  }): [Games.Slug, Bets.Slug] => [
    requireUrlParameter(Games.Slug, "game", ctx.params["gameSlug"]),
    requireUrlParameter(Bets.Slug, "bet", ctx.params["betSlug"]),
  ];

  // Get Bet.
  router.get("/", async (ctx) => {
    const [gameSlug, betSlug] = slugs(ctx);
    const game = await server.store.getGame(gameSlug);
    if (game === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Game not found.");
    }
    const bet = await server.store.getBet(gameSlug, betSlug);
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    ctx.body = Schema.strict({
      game: Games.Game,
      bet: Bets.Bet,
    }).encode({
      game: Games.withBetStatsFromInternal(game)[1],
      bet: Bets.fromInternal(bet)[1],
    });
  });

  router.get("/edit", async (ctx) => {
    const [gameSlug, betSlug] = slugs(ctx);
    const bet = await server.store.getBet(gameSlug, betSlug);
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    ctx.body = Editor.Bets.EditableBet.encode(Editor.Bets.fromInternal(bet));
  });

  // Create Bet
  router.put("/", body, async (ctx) => {
    const sessionCookie = Auth.requireSession(ctx.cookies);
    const [gameSlug, betSlug] = slugs(ctx);
    const body = Validation.body(CreateBetBody, ctx.request.body);
    const bet = await server.store.addBet(
      sessionCookie.user,
      sessionCookie.session,
      gameSlug,
      betSlug,
      body.name,
      body.description,
      body.spoiler,
      body.lockMoment,
      body.addOptions,
    );
    ctx.body = Editor.Bets.EditableBet.encode(Editor.Bets.fromInternal(bet));
  });

  // Edit Bet
  router.post("/", body, async (ctx) => {
    const sessionCookie = Auth.requireSession(ctx.cookies);
    const [gameSlug, betSlug] = slugs(ctx);
    const body = Validation.body(EditBetBody, ctx.request.body);
    const bet = await server.store.editBet(
      sessionCookie.user,
      sessionCookie.session,
      gameSlug,
      betSlug,
      body.version,
      body.name,
      body.description,
      body.spoiler,
      body.lockMoment,
      body.removeOptions,
      body.editOptions,
      body.addOptions,
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    ctx.body = Editor.Bets.EditableBet.encode(Editor.Bets.fromInternal(bet));
  });

  // Complete Bet
  router.post("/complete", body, async (ctx) => {
    const sessionCookie = Auth.requireSession(ctx.cookies);
    const [gameSlug, betSlug] = slugs(ctx);
    const body = Validation.body(CompleteBetBody, ctx.request.body);
    const bet = await server.store.completeBet(
      sessionCookie.user,
      sessionCookie.session,
      gameSlug,
      betSlug,
      body.version,
      body.winners,
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    ctx.body = Editor.Bets.EditableBet.encode(Editor.Bets.fromInternal(bet));
  });

  // Revert Complete Bet
  router.post("/complete/revert", body, async (ctx) => {
    const sessionCookie = Auth.requireSession(ctx.cookies);
    const [gameSlug, betSlug] = slugs(ctx);
    const body = Validation.body(RevertBody, ctx.request.body);
    const bet = await server.store.revertCompleteBet(
      sessionCookie.user,
      sessionCookie.session,
      gameSlug,
      betSlug,
      body.version,
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    ctx.body = Editor.Bets.EditableBet.encode(Editor.Bets.fromInternal(bet));
  });

  // Lock Bet
  router.post("/lock", body, async (ctx) => {
    const sessionCookie = Auth.requireSession(ctx.cookies);
    const [gameSlug, betSlug] = slugs(ctx);
    const body = Validation.body(ModifyLockStateBody, ctx.request.body);
    const bet = await server.store.setBetLocked(
      sessionCookie.user,
      sessionCookie.session,
      gameSlug,
      betSlug,
      body.version,
      true,
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    ctx.body = Editor.Bets.EditableBet.encode(Editor.Bets.fromInternal(bet));
  });

  // Unlock Bet
  router.post("/unlock", body, async (ctx) => {
    const sessionCookie = Auth.requireSession(ctx.cookies);
    const [gameSlug, betSlug] = slugs(ctx);
    const body = Validation.body(ModifyLockStateBody, ctx.request.body);
    const bet = await server.store.setBetLocked(
      sessionCookie.user,
      sessionCookie.session,
      gameSlug,
      betSlug,
      body.version,
      false,
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    ctx.body = Editor.Bets.EditableBet.encode(Editor.Bets.fromInternal(bet));
  });

  // Cancel Bet
  router.post("/cancel", body, async (ctx) => {
    const sessionCookie = Auth.requireSession(ctx.cookies);
    const [gameSlug, betSlug] = slugs(ctx);
    const body = Validation.body(CancelBetBody, ctx.request.body);
    const bet = await server.store.cancelBet(
      sessionCookie.user,
      sessionCookie.session,
      gameSlug,
      betSlug,
      body.version,
      body.reason,
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    ctx.body = Editor.Bets.EditableBet.encode(Editor.Bets.fromInternal(bet));
  });

  // Revert Cancel Bet
  router.post("/cancel/revert", body, async (ctx) => {
    const sessionCookie = Auth.requireSession(ctx.cookies);
    const [gameSlug, betSlug] = slugs(ctx);
    const body = Validation.body(RevertBody, ctx.request.body);
    const bet = await server.store.revertCancelBet(
      sessionCookie.user,
      sessionCookie.session,
      gameSlug,
      betSlug,
      body.version,
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    ctx.body = Editor.Bets.EditableBet.encode(Editor.Bets.fromInternal(bet));
  });

  // Get Bet Feed
  router.get("/feed", async (ctx) => {
    const [gameSlug, betSlug] = slugs(ctx);
    const feed = await server.store.getBetFeed(gameSlug, betSlug);
    ctx.body = Schema.readonlyArray(Feed.Event).encode(
      feed.map(Feed.fromInternal),
    );
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
  router.put("/options/:optionSlug/stake", body, async (ctx) => {
    const sessionCookie = Auth.requireSession(ctx.cookies);
    const [gameSlug, betSlug] = slugs(ctx);
    const optionSlug = requireUrlParameter(
      Bets.Options.Slug,
      "option",
      ctx.params["optionSlug"],
    );
    const { amount, message } = validateStakeBody(ctx.request.body);
    ctx.body = Schema.Int.encode(
      (await server.store.newStake(
        sessionCookie.user,
        sessionCookie.session,
        gameSlug,
        betSlug,
        optionSlug,
        amount,
        message ?? null,
      )) as Schema.Int,
    );
  });

  // Edit Stake.
  router.post("/options/:optionSlug/stake", body, async (ctx) => {
    const sessionCookie = Auth.requireSession(ctx.cookies);
    const [gameSlug, betSlug] = slugs(ctx);
    const optionSlug = requireUrlParameter(
      Bets.Options.Slug,
      "option",
      ctx.params["optionSlug"],
    );
    const { amount, message } = validateStakeBody(ctx.request.body);
    ctx.body = Schema.Int.encode(
      (await server.store.changeStake(
        sessionCookie.user,
        sessionCookie.session,
        gameSlug,
        betSlug,
        optionSlug,
        amount,
        message ?? null,
      )) as Schema.Int,
    );
  });

  // Withdraw Stake.
  router.delete("/options/:optionSlug/stake", body, async (ctx) => {
    const sessionCookie = Auth.requireSession(ctx.cookies);
    const [gameSlug, betSlug] = slugs(ctx);
    const optionSlug = requireUrlParameter(
      Bets.Options.Slug,
      "option",
      ctx.params["optionSlug"],
    );
    ctx.body = Schema.Int.encode(
      (await server.store.withdrawStake(
        sessionCookie.user,
        sessionCookie.session,
        gameSlug,
        betSlug,
        optionSlug,
      )) as Schema.Int,
    );
  });

  return router;
};
