import * as Joda from "@js-joda/core";
import parseInterval from "postgres-interval";
import { z } from "zod";

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

export * as Types from "./types.js";
