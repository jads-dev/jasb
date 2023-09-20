import { default as Router } from "@koa/router";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";

import { Banners } from "../../../../public/gacha/banners.js";
import { CardTypes } from "../../../../public/gacha/card-types.js";
import { Cards } from "../../../../public/gacha/cards.js";
import { Credits } from "../../../../public/gacha/credits.js";
import { Rarities } from "../../../../public/gacha/rarities.js";
import { Users } from "../../../../public/users.js";
import { Validation } from "../../../../util/validation.js";
import { WebError } from "../../../errors.js";
import type { Server } from "../../../model.js";
import { requireSession } from "../../auth.js";
import { body } from "../../util.js";

const {
  remove: removeCredits,
  edit: editCredits,
  add: addCredits,
} = Validation.addEditRemove(Credits.Id, {
  reason: Schema.string,
  credited: Schema.union([
    Schema.strict({ user: Users.Slug }),
    Schema.strict({ name: Schema.string }),
  ]),
});

const CardTypeBody = {
  name: Schema.string,
  description: Schema.string,
  image: Schema.string,
  retired: Schema.boolean,
  rarity: Rarities.Slug,
  layout: Cards.Layout,
};
const AddCardTypeBody = Schema.readonly(
  Schema.strict({ ...CardTypeBody, credits: addCredits }),
);
const EditCardTypeBody = Schema.intersection([
  Schema.partial({ ...CardTypeBody, removeCredits, editCredits, addCredits }),
  Schema.strict({ version: Schema.Int }),
]);

const GiftSelfMadeCardBody = Schema.readonly(
  Schema.strict({
    user: Users.Slug,
  }),
);

export const cardTypesApi = (server: Server.State): Router => {
  const router = new Router();

  // Get the editable card types in the given banner.
  router.get("/edit", async (ctx) => {
    const bannerSlug = Validation.requireUrlParameter(
      Banners.Slug,
      "banner",
      ctx.params["bannerSlug"],
    );
    const cardTypes = await server.store.gachaGetCardTypes(bannerSlug);
    ctx.body = Schema.readonlyArray(
      Schema.tuple([CardTypes.Id, CardTypes.EditableCardType]),
    ).encode(cardTypes.map(CardTypes.editableFromInternal));
  });

  // Get the detailed card type.
  router.get("/:cardTypeId", async (ctx) => {
    const bannerSlug = Validation.requireUrlParameter(
      Banners.Slug,
      "banner",
      ctx.params["bannerSlug"],
    );
    const cardTypeId = Validation.requireNumberUrlParameter(
      CardTypes.Id,
      "card type",
      ctx.params["cardTypeId"],
    );
    const cardType = await server.store.gachaGetCardType(
      bannerSlug,
      cardTypeId,
    );
    if (cardType === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Card type not found.");
    }
    ctx.body = CardTypes.Detailed.encode(
      CardTypes.detailedFromInternal(cardType)[1],
    );
  });

  // Gift a self-made card to someone.
  router.post("/:cardTypeId/gift", body, async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const bannerSlug = Validation.requireUrlParameter(
      Banners.Slug,
      "banner",
      ctx.params["bannerSlug"],
    );
    const cardTypeId = Validation.requireNumberUrlParameter(
      CardTypes.Id,
      "card type",
      ctx.params["cardTypeId"],
    );
    const body = Validation.body(GiftSelfMadeCardBody, ctx.request.body);
    const cardType = await server.store.gachaGiftSelfMadeCard(
      sessionCookie.user,
      sessionCookie.session,
      body.user,
      bannerSlug,
      cardTypeId,
    );
    ctx.body = Schema.tuple([Cards.Id, Cards.Card]).encode(
      Cards.fromInternal(cardType),
    );
  });

  // Create new card type in the given banner.
  router.post("/", body, async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const bannerSlug = Validation.requireUrlParameter(
      Banners.Slug,
      "banner",
      ctx.params["bannerSlug"],
    );
    const body = Validation.body(AddCardTypeBody, ctx.request.body);
    const cardType = await server.store.gachaAddCardType(
      sessionCookie.user,
      sessionCookie.session,
      bannerSlug,
      body.name,
      body.description,
      body.image,
      body.rarity,
      body.layout,
      body.credits,
    );
    ctx.body = Schema.tuple([CardTypes.Id, CardTypes.EditableCardType]).encode(
      CardTypes.editableFromInternal(cardType),
    );
  });

  // Edit a card type in the given banner.
  router.post("/:cardTypeId", body, async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const bannerSlug = Validation.requireUrlParameter(
      Banners.Slug,
      "banner",
      ctx.params["bannerSlug"],
    );
    const cardTypeId = Validation.requireNumberUrlParameter(
      CardTypes.Id,
      "card type",
      ctx.params["cardTypeId"],
    );
    const body = Validation.body(EditCardTypeBody, ctx.request.body);
    const cardType = await server.store.gachaEditCardType(
      sessionCookie.user,
      sessionCookie.session,
      bannerSlug,
      cardTypeId,
      body.version,
      body.name ?? null,
      body.description ?? null,
      body.image ?? null,
      body.rarity ?? null,
      body.layout ?? null,
      body.retired ?? null,
      body.removeCredits ?? [],
      body.editCredits ?? [],
      body.addCredits ?? [],
    );
    ctx.body = Schema.tuple([CardTypes.Id, CardTypes.EditableCardType]).encode(
      CardTypes.editableFromInternal(cardType),
    );
  });

  return router;
};
