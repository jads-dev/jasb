import { default as Router } from "@koa/router";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";

import { Balance } from "../../../public/gacha/balances.js";
import { Banners } from "../../../public/gacha/banners.js";
import { CardTypes } from "../../../public/gacha/card-types.js";
import { Cards } from "../../../public/gacha/cards.js";
import { Validation } from "../../../util/validation.js";
import { WebError } from "../../errors.js";
import type { Server } from "../../model.js";
import { requireSession } from "../auth.js";
import { body } from "../util.js";
import { cardTypesApi } from "./banners/card-types.js";

const BannerBody = {
  name: Schema.string,
  description: Schema.string,
  cover: Schema.string,
  active: Schema.boolean,
  type: Schema.string,
  backgroundColor: Validation.HexAlphaColor,
  foregroundColor: Validation.HexAlphaColor,
};
const AddBannerBody = Schema.readonly(Schema.strict(BannerBody));
const EditBannerBody = Schema.intersection([
  Schema.partial(BannerBody),
  Schema.strict({ version: Schema.Int }),
]);

const ReorderBannersBody = Schema.readonlyArray(
  Schema.tuple([Banners.Slug, Schema.Int]),
);

const RollBody = Schema.readonly(
  Schema.partial({
    count: Schema.union([Schema.literal(1), Schema.literal(10)]),
    guarantee: Schema.boolean,
  }),
);

export const bannersApi = (server: Server.State): Router => {
  const router = new Router();

  // Get all active banners.
  router.get("/", async (ctx) => {
    const banners = await server.store.gachaGetBanners();
    ctx.body = Schema.readonlyArray(
      Schema.tuple([Banners.Slug, Banners.Banner]),
    ).encode(banners.map(Banners.fromInternal));
  });

  // Reorder banners.
  router.post("/", body, async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const body = Validation.body(ReorderBannersBody, ctx.request.body);
    const banners = await server.store.gachaReorderBanners(
      sessionCookie.user,
      sessionCookie.session,
      body,
    );
    ctx.body = Schema.readonlyArray(
      Schema.tuple([Banners.Slug, Banners.Editable]),
    ).encode(banners.map(Banners.editableFromInternal));
  });

  // Get editable banners.
  router.get("/edit", async (ctx) => {
    const results = await server.store.gachaGetEditableBanners();
    ctx.body = Schema.readonlyArray(
      Schema.tuple([Banners.Slug, Banners.Editable]),
    ).encode(results.map(Banners.editableFromInternal));
  });

  // Get a banner with its card types to preview.
  router.get("/:bannerSlug", async (ctx) => {
    const bannerSlug = Validation.requireUrlParameter(
      Banners.Slug,
      "banner",
      ctx.params["bannerSlug"],
    );
    const [banner, cardTypes] = await Promise.all([
      server.store.gachaGetBanner(bannerSlug),
      server.store.gachaGetCardTypes(bannerSlug),
    ]);
    if (banner === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Banner not found.");
    }
    ctx.body = Schema.strict({
      banner: Banners.Banner,
      cardTypes: Schema.readonlyArray(CardTypes.WithId),
    }).encode({
      banner: Banners.fromInternal(banner)[1],
      cardTypes: cardTypes.map(CardTypes.fromInternal),
    });
  });

  // Create new banner.
  router.put("/:bannerSlug", body, async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const bannerSlug = Validation.requireUrlParameter(
      Banners.Slug,
      "banner",
      ctx.params["bannerSlug"],
    );
    const body = Validation.body(AddBannerBody, ctx.request.body);
    const banner = await server.store.gachaAddBanner(
      sessionCookie.user,
      sessionCookie.session,
      bannerSlug,
      body.name,
      body.description,
      body.cover,
      body.active,
      body.type,
      body.backgroundColor,
      body.foregroundColor,
    );
    ctx.body = Schema.tuple([Banners.Slug, Banners.Editable]).encode(
      Banners.editableFromInternal(banner),
    );
  });

  // Edit a banner.
  router.post("/:bannerSlug", body, async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const bannerSlug = Validation.requireUrlParameter(
      Banners.Slug,
      "banner",
      ctx.params["bannerSlug"],
    );
    const body = Validation.body(EditBannerBody, ctx.request.body);
    const banner = await server.store.gachaEditBanner(
      sessionCookie.user,
      sessionCookie.session,
      bannerSlug,
      body.version,
      body.name ?? null,
      body.description ?? null,
      body.cover ?? null,
      body.active ?? null,
      body.type ?? null,
      body.backgroundColor ?? null,
      body.foregroundColor ?? null,
    );
    ctx.body = Schema.tuple([Banners.Slug, Banners.Editable]).encode(
      Banners.editableFromInternal(banner),
    );
  });

  // Roll a card.
  router.post("/:bannerSlug/roll", body, async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const bannerSlug = Validation.requireUrlParameter(
      Banners.Slug,
      "banner",
      ctx.params["bannerSlug"],
    );
    const body = Validation.body(RollBody, ctx.request.body);
    const cards = await server.store.gachaRoll(
      sessionCookie.user,
      sessionCookie.session,
      bannerSlug,
      body.count === 10 ? 10 : 1,
      body.guarantee ?? false,
    );
    const balance = await server.store.gachaGetBalance(
      sessionCookie.user,
      sessionCookie.session,
    );
    ctx.body = Schema.readonly(
      Schema.strict({
        cards: Schema.readonlyArray(Schema.tuple([Cards.Id, Cards.Card])),
        balance: Balance,
      }),
    ).encode({ cards: cards.map(Cards.fromInternal), balance });
  });

  const cardTypes = cardTypesApi(server);
  router.use(
    "/:bannerSlug/card-types",
    cardTypes.routes(),
    cardTypes.allowedMethods(),
  );

  return router;
};
