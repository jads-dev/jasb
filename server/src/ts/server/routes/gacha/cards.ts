import { default as Router } from "@koa/router";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";

import { Rarities } from "../../../public/gacha.js";
import { Balances } from "../../../public/gacha/balances.js";
import { Banners } from "../../../public/gacha/banners.js";
import { CardTypes } from "../../../public/gacha/card-types.js";
import { Cards } from "../../../public/gacha/cards.js";
import { Users } from "../../../public/users.js";
import { Urls } from "../../../util/urls.js";
import { requireUrlParameter, Validation } from "../../../util/validation.js";
import { Credentials } from "../../auth/credentials.js";
import { WebError } from "../../errors.js";
import type { Server } from "../../model.js";
import { body } from "../util.js";

const EditHighlightBody = Schema.readonly(
  Schema.partial({
    message: Schema.union([Schema.string, Schema.null]),
  }),
);

const ReorderHighlightsBody = Schema.readonlyArray(Cards.Id);

const ForgeCardBody = Schema.readonly(
  Schema.strict({
    quote: Schema.string,
    rarity: Rarities.Slug,
  }),
);
const ForgeCardResponse = Schema.readonly(
  Schema.strict({
    forged: CardTypes.WithId,
    balance: Balances.Balance,
  }),
);

export const cardsApi = (server: Server.State): Router => {
  const router = new Router();

  // Redirect to the card collection for the logged-in user.
  router.get("/", async (ctx) => {
    const credential = await server.auth.requireIdentifyingCredential(ctx);
    // We don't actually validate this credential, but this redirect is safe to do anyway, so that's fine.
    ctx.redirect(`/api/user/${Credentials.actingUser(credential)}`);
    ctx.status = StatusCodes.TEMPORARY_REDIRECT;
  });

  // Get the card collection for the logged-in user.
  router.get("/:userSlug", async (ctx) => {
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    const [user, highlighted, banners] = await Promise.all([
      server.store.getUser(userSlug),
      server.store.gachaGetHighlighted(userSlug),
      server.store.gachaGetCollectionBanners(userSlug),
    ]);
    if (user === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "User not found.");
    } else {
      ctx.body = Schema.strict({
        user: Schema.tuple([Users.Slug, Users.Summary]),
        highlighted: Schema.readonlyArray(
          Schema.tuple([Banners.Slug, Cards.Id, Cards.Highlight]),
        ),
        banners: Schema.readonlyArray(
          Schema.tuple([Banners.Slug, Banners.Banner]),
        ),
      }).encode({
        user: Users.summaryFromInternal(user),
        highlighted: highlighted.map(Cards.highlightedFromInternal),
        banners: banners.map(Banners.fromInternal),
      });
    }
  });

  // Forge a card type for the user.
  router.post("/:userSlug/forge", body, async (ctx) => {
    const credential = await server.auth.requireIdentifyingCredential(ctx);
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    Credentials.ensureCanActAs(credential, userSlug);
    const body = Validation.body(ForgeCardBody, ctx.request.body);
    const { name, image } = await server.store.gachaGetForgeDetail(userSlug);
    const imageUpload = server.imageUpload;
    if (imageUpload === undefined) {
      throw new WebError(
        StatusCodes.SERVICE_UNAVAILABLE,
        "Image uploading not available.",
      );
    }
    const sourceUrl = `${image}?size=4096`;

    const tryGet = async (): Promise<{
      mimeType: string;
      data: Uint8Array;
    }> => {
      const sourceImage = await fetch(sourceUrl);
      if (sourceImage.body === null) {
        throw new WebError(
          StatusCodes.SERVICE_UNAVAILABLE,
          "Unable to fetch avatar from Discord.",
        );
      }
      const mimeType = sourceImage.headers.get("Content-Type");
      if (mimeType === null) {
        throw new WebError(
          StatusCodes.SERVICE_UNAVAILABLE,
          "Discord did not provide mime type.",
        );
      }
      try {
        return {
          mimeType,
          data: new Uint8Array(await sourceImage.arrayBuffer()),
        };
      } catch (error: unknown) {
        throw new WebError(
          StatusCodes.SERVICE_UNAVAILABLE,
          "Failure processing avatar from Discord.",
        );
      }
    };
    const imageResolved = await tryGet();
    const imageUrl = await imageUpload.upload(
      Urls.extractFilename(sourceUrl),
      imageResolved.mimeType,
      imageResolved.data,
      { uploader: userSlug, reason: "forge-card-type", source: sourceUrl },
    );
    const cardType = await server.store.gachaForgeCardType(
      credential,
      name,
      imageUrl.toString(),
      `“${body.quote}”`,
      body.rarity,
    );
    const balance = await server.store.gachaGetBalance(credential);
    ctx.body = ForgeCardResponse.encode({
      forged: CardTypes.fromInternal(cardType),
      balance: Balances.fromInternal(balance),
    });
  });

  // Get the forged card types for the user.
  router.get("/:userSlug/forged", async (ctx) => {
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    const cardTypes = await server.store.gachaGetUserForgeCardsTypes(userSlug);
    ctx.body = Schema.readonlyArray(
      Schema.union([CardTypes.WithId, Rarities.WithSlug]),
    ).encode(cardTypes.map(CardTypes.optionalByRarity));
  });

  // Retire a forged card type from the user.
  router.post("/:userSlug/forged/:cardTypeId/retire", async (ctx) => {
    const credential = await server.auth.requireIdentifyingCredential(ctx);
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    Credentials.ensureCanActAs(credential, userSlug);
    const cardTypeId = Validation.requireNumberUrlParameter(
      CardTypes.Id,
      "card type",
      ctx.params["cardTypeId"],
    );
    const cardType = await server.store.gachaRetireForgedCardType(
      credential,
      cardTypeId,
    );
    ctx.body = CardTypes.WithId.encode(CardTypes.fromInternal(cardType));
  });

  // Get the card collection for the logged-in user in the given banner.
  router.get("/:userSlug/banners/:bannerSlug", async (ctx) => {
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    const bannerSlug = requireUrlParameter(
      Banners.Slug,
      "banner",
      ctx.params["bannerSlug"],
    );
    const [user, banner, cardTypes] = await Promise.all([
      server.store.getUser(userSlug),
      server.store.gachaGetEditableBanner(bannerSlug),
      server.store.gachaGetCollectionCards(userSlug, bannerSlug),
    ]);
    if (user === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "User not found.");
    } else if (banner === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Banner not found.");
    } else {
      ctx.body = Schema.strict({
        user: Schema.tuple([Users.Slug, Users.Summary]),
        banner: Banners.WithSlug,
        cards: Schema.readonlyArray(
          Schema.tuple([CardTypes.Id, CardTypes.WithCards]),
        ),
      }).encode({
        user: Users.summaryFromInternal(user),
        banner: Banners.fromInternal(banner),
        cards: cardTypes.map(CardTypes.withCardsFromInternal),
      });
    }
  });

  // Recycle value of the given card.
  router.get("/:userSlug/banners/:bannerSlug/:cardId/value", async (ctx) => {
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    const bannerSlug = requireUrlParameter(
      Banners.Slug,
      "banner",
      ctx.params["bannerSlug"],
    );
    const cardId = Validation.requireNumberUrlParameter(
      Cards.Id,
      "card",
      ctx.params["cardId"],
    );
    const value = await server.store.gachaRecycleValue(
      userSlug,
      bannerSlug,
      cardId,
    );
    ctx.body = Balances.Value.encode(Balances.valueFromInternal(value));
  });

  // Recycle the given card.
  router.delete("/:userSlug/banners/:bannerSlug/:cardId", async (ctx) => {
    const credential = await server.auth.requireIdentifyingCredential(ctx);
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    const cardId = Validation.requireNumberUrlParameter(
      Cards.Id,
      "card",
      ctx.params["cardId"],
    );
    Credentials.ensureCanActAs(credential, userSlug);
    const balance = await server.store.gachaRecycleCard(credential, cardId);
    ctx.body = Balances.Balance.encode(Balances.fromInternal(balance));
  });

  // Reorder the highlights.
  router.post("/:userSlug/highlights", body, async (ctx) => {
    const credential = await server.auth.requireIdentifyingCredential(ctx);
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    Credentials.ensureCanActAs(credential, userSlug);
    const body = Validation.body(ReorderHighlightsBody, ctx.request.body);
    const highlights = await server.store.gachaSetHighlightsOrder(
      credential,
      body,
    );
    ctx.body = Schema.readonlyArray(
      Schema.tuple([Banners.Slug, Cards.Id, Cards.Highlight]),
    ).encode(highlights.map(Cards.highlightedFromInternal));
  });

  // Get the detailed version of the given card.
  router.get("/:userSlug/banners/:bannerSlug/:cardId", async (ctx) => {
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    const cardId = Validation.requireNumberUrlParameter(
      Cards.Id,
      "card",
      ctx.params["cardId"],
    );
    const card = await server.store.gachaGetDetailedCard(userSlug, cardId);
    ctx.body = Cards.Detailed.encode(Cards.detailedFromInternal(card)[1]);
  });

  // Highlight the given card.
  router.put(
    "/:userSlug/banners/:bannerSlug/:cardId/highlight",
    async (ctx) => {
      const credential = await server.auth.requireIdentifyingCredential(ctx);
      const userSlug = requireUrlParameter(
        Users.Slug,
        "user",
        ctx.params["userSlug"],
      );
      const cardId = Validation.requireNumberUrlParameter(
        Cards.Id,
        "card",
        ctx.params["cardId"],
      );
      Credentials.ensureCanActAs(credential, userSlug);
      const highlight = await server.store.gachaSetHighlight(
        credential,
        cardId,
        true,
      );
      ctx.body = Cards.Highlight.encode(
        Cards.highlightedFromInternal(highlight)[2],
      );
    },
  );

  // Edit the given card highlight.
  router.post(
    "/:userSlug/banners/:bannerSlug/:cardId/highlight",
    body,
    async (ctx) => {
      const credential = await server.auth.requireIdentifyingCredential(ctx);
      const userSlug = requireUrlParameter(
        Users.Slug,
        "user",
        ctx.params["userSlug"],
      );
      const cardId = Validation.requireNumberUrlParameter(
        Cards.Id,
        "card",
        ctx.params["cardId"],
      );
      Credentials.ensureCanActAs(credential, userSlug);
      const body = Validation.body(EditHighlightBody, ctx.request.body);
      if (body.message !== null && body.message !== undefined) {
        if (body.message.length < 1) {
          throw new WebError(
            StatusCodes.BAD_REQUEST,
            "Message must be non-empty.",
          );
        } else if (body.message.length > 512) {
          throw new WebError(StatusCodes.BAD_REQUEST, "Message too long.");
        }
      }
      const highlight = await server.store.gachaEditHighlight(
        credential,
        cardId,
        body.message,
      );

      ctx.body = Cards.Highlight.encode(
        Cards.highlightedFromInternal(highlight)[2],
      );
    },
  );

  // Remove highlight of the given card.
  router.delete(
    "/:userSlug/banners/:bannerSlug/:cardId/highlight",
    async (ctx) => {
      const credential = await server.auth.requireIdentifyingCredential(ctx);
      const userSlug = requireUrlParameter(
        Users.Slug,
        "user",
        ctx.params["userSlug"],
      );
      const cardId = Validation.requireNumberUrlParameter(
        Cards.Id,
        "card",
        ctx.params["cardId"],
      );
      Credentials.ensureCanActAs(credential, userSlug);
      const result = await server.store.gachaSetHighlight(
        credential,
        cardId,
        false,
      );
      ctx.body = Cards.Id.encode(result.id);
    },
  );

  return router;
};
