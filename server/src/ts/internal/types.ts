import * as Joda from "@js-joda/core";
import * as Schema from "io-ts";
import parseInterval from "postgres-interval";
import { z } from "zod";

import { Public } from "../public.js";

export const wrapSchema = <Parsed, Encoded>(
  schema: Schema.Type<Parsed, Encoded>,
) => z.custom<Parsed>((value) => schema.is(value));

export const cardId = wrapSchema(Public.Gacha.Cards.Id);
export const cardTypeId = wrapSchema(Public.Gacha.CardTypes.Id);
export const qualitySlug = wrapSchema(Public.Gacha.Qualities.Slug);
export const raritySlug = wrapSchema(Public.Gacha.Rarities.Slug);
export const bannerSlug = wrapSchema(Public.Gacha.Banners.Slug);
export const userSlug = wrapSchema(Public.Users.Slug);
export const gameSlug = wrapSchema(Public.Games.Slug);
export const optionSlug = wrapSchema(Public.Bets.Options.Slug);
export const betSlug = wrapSchema(Public.Bets.Slug);
export const lockMomentSlug = wrapSchema(Public.Editor.LockMoments.Slug);
export const notificationId = wrapSchema(Public.Notifications.Id);
export const creditId = wrapSchema(Public.Gacha.Credits.Id);

export const int = z
  .number()
  .int()
  .transform((number) => number as Schema.Int);

export const nonNegativeInt = z
  .number()
  .int()
  .nonnegative()
  .transform((number) => number as Schema.Int);

export const positiveInt = z
  .number()
  .int()
  .positive()
  .transform((number) => number as Schema.Int);

const postgresDateTimeFormatter = new Joda.DateTimeFormatterBuilder()
  .parseCaseInsensitive()
  .append(Joda.DateTimeFormatter.ISO_LOCAL_DATE)
  .appendLiteral(" ")
  .append(Joda.DateTimeFormatter.ISO_LOCAL_TIME)
  .optionalStart()
  .appendOffset("+HH", "Z")
  .optionalEnd()
  .toFormatter(Joda.ResolverStyle.STRICT);

export const zonedDateTime = z.string().transform((value, context) => {
  try {
    return Joda.ZonedDateTime.parse(value, postgresDateTimeFormatter);
  } catch {
    // When we get as part of JSON, it'll be ISO style, so check that too.
    try {
      return Joda.ZonedDateTime.parse(
        value,
        Joda.DateTimeFormatter.ISO_ZONED_DATE_TIME,
      );
    } catch {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: `Invalid timestamptz ("${value}"), could not parse.`,
      });
      return Joda.ZonedDateTime.of(Joda.LocalDateTime.MIN, Joda.ZoneId.UTC);
    }
  }
});

export const localDate = z.string().transform((value, context) => {
  try {
    return Joda.LocalDate.parse(value);
  } catch {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      message: `Invalid date ("${value}"), could not parse.`,
    });
    return Joda.LocalDate.MIN;
  }
});

export const duration = z.string().transform((value, context) => {
  try {
    return Joda.Duration.parse(parseInterval(value).toISOString());
  } catch {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      message: `Invalid duration ("${value}"), could not parse.`,
    });
    return Joda.Duration.ZERO;
  }
});

const validByteA = /^\\x(?<hex>[a-fA-F0-9]*)$/;
export const buffer = z.string().transform((value, context) => {
  const hex = validByteA.exec(value)?.groups?.["hex"];
  if (hex === undefined) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      message: `Not a valid bytea hex string, (got “${value}”).`,
    });
    return Buffer.alloc(0);
  } else {
    return Buffer.from(hex, "hex");
  }
});

export const color = buffer.transform((value, context) => {
  if (value.length != 4) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      message: `Invalid colour, must be 4 bytes, not ${value.length} bytes).`,
    });
    return Buffer.from("00000000");
  } else {
    return value;
  }
});

export * as Types from "./types.js";
