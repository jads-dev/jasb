import { Cards } from "../../public/gacha/cards.js";
import { Expect } from "../../util/expect.js";
import { Pipeline } from "./pipelines.js";

export type TypeName = "avatar" | "cover" | "option" | "card" | "banner";

export interface Type {
  name: TypeName;
  prefix: string;
  table: string;
  objectColumn: string;
}

export interface ProcessedType {
  type: Type;
  pipeline: Pipeline;
}

export const avatarType: Type = {
  name: "avatar",
  prefix: "avatars/",
  table: "users",
  objectColumn: "avatar",
};

export const gameCoverType: Type = {
  name: "cover",
  prefix: "covers/",
  table: "games",
  objectColumn: "cover",
};
export const gameCoverTypeProcess: ProcessedType = {
  type: gameCoverType,
  pipeline: Pipeline.input().toWebP({ targetSize: [384, 512] }),
};

export const optionImage: Type = {
  name: "option",
  prefix: "options/",
  table: "options",
  objectColumn: "image",
};
export const optionImageProcess: ProcessedType = {
  type: optionImage,
  pipeline: Pipeline.input().toWebP({ targetSize: [256, 256] }),
};

export const cardImage: Type = {
  name: "card",
  prefix: "cards/",
  table: "gacha_card_types",
  objectColumn: "image",
};
const layoutToTargetSize = (cardLayout: Cards.Layout): [number, number] => {
  switch (cardLayout) {
    case "Normal":
      return [640, 640];
    case "FullImage":
      return [640, 1024];
    case "LandscapeFullImage":
      return [1024, 640];
    default:
      return Expect.exhaustive("card layout")(cardLayout);
  }
};
export const cardImageProcess = (cardLayout: Cards.Layout): ProcessedType => ({
  type: cardImage,
  pipeline: Pipeline.input().toWebP({
    targetSize: layoutToTargetSize(cardLayout),
  }),
});

export const bannerCover: Type = {
  name: "banner",
  prefix: "banners/",
  table: "gacha_banners",
  objectColumn: "cover",
};
export const bannerCoverProcess: ProcessedType = {
  type: bannerCover,
  pipeline: Pipeline.input().toWebP({ targetSize: [2048, 512] }),
};

export const allTypes: readonly Type[] = [
  avatarType,
  gameCoverType,
  optionImage,
  cardImage,
  bannerCover,
];

export * as Objects from "./types.js";
