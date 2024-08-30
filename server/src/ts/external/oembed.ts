import * as Schema from "io-ts";

export const OEmbed = Schema.readonly(
  Schema.strict({
    type: Schema.literal("link"),
    version: Schema.literal("1.0"),
    title: Schema.string,
    thumbnail_url: Schema.string,
  }),
);
export type OEmbed = Schema.TypeOf<typeof OEmbed>;
