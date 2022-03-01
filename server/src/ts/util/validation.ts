import * as Joda from "@js-joda/core";
import { either as Either } from "fp-ts";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";
import { default as Reporters } from "io-ts-reporters";

import { WebError } from "../server/errors.js";
import { PlaceholderSecretToken, SecretToken } from "./secret-token.js";

export const Duration = new Schema.Type<Joda.Duration, string, unknown>(
  "Duration",
  (value: unknown): value is Joda.Duration => value instanceof Joda.Duration,
  (input: unknown, context: Schema.Context) =>
    Either.chain((value: string): Schema.Validation<Joda.Duration> => {
      try {
        return Schema.success(Joda.Duration.parse(value));
      } catch (error) {
        if (error instanceof Joda.DateTimeParseException) {
          return Schema.failure(
            input,
            context,
            `not a valid ISO 8601 duration: ${value}`,
          );
        } else {
          throw error;
        }
      }
    })(Schema.string.validate(input, context)),
  (value) => value.toString(),
);

export const DateTime = new Schema.Type<Joda.ZonedDateTime, string, unknown>(
  "DateTime",
  (value: unknown): value is Joda.ZonedDateTime =>
    value instanceof Joda.ZonedDateTime,
  (input: unknown, context: Schema.Context) =>
    Either.chain((value: string): Schema.Validation<Joda.ZonedDateTime> => {
      try {
        return Schema.success(Joda.ZonedDateTime.parse(value));
      } catch (error) {
        if (error instanceof Joda.DateTimeParseException) {
          return Schema.failure(
            input,
            context,
            `not a valid ISO 8601 date & time: ${value}`,
          );
        } else {
          throw error;
        }
      }
    })(Schema.string.validate(input, context)),
  (value) => value.toString(),
);

export const Date = new Schema.Type<Joda.LocalDate, string, unknown>(
  "Date",
  (value: unknown): value is Joda.LocalDate => value instanceof Joda.LocalDate,
  (input: unknown, context: Schema.Context) =>
    Either.chain((value: string): Schema.Validation<Joda.LocalDate> => {
      try {
        return Schema.success(Joda.LocalDate.parse(value));
      } catch (error) {
        if (error instanceof Joda.DateTimeParseException) {
          return Schema.failure(
            input,
            context,
            `not a valid ISO 8601 date: ${value}`,
          );
        } else {
          throw error;
        }
      }
    })(Schema.string.validate(input, context)),
  (value) => value.toString(),
);

export const SecretTokenUri = new Schema.Type<SecretToken, string, unknown>(
  "SecretTokenUri",
  (u): u is SecretToken => u instanceof SecretToken,
  (input, context) =>
    Either.chain((value: string): Schema.Validation<SecretToken> => {
      const token = SecretToken.fromUri(value);
      return token !== undefined
        ? Schema.success(token)
        : Schema.failure(
            input,
            context,
            `not a valid secret token URI: ${value}`,
          );
    })(Schema.string.validate(input, context)),
  (a) => a.uri,
);

export const Placeholder = new Schema.Type<
  PlaceholderSecretToken,
  string,
  unknown
>(
  "Placeholder",
  (u): u is PlaceholderSecretToken => u instanceof PlaceholderSecretToken,
  (input, context) =>
    Either.chain((value: string): Schema.Validation<PlaceholderSecretToken> => {
      return value === PlaceholderSecretToken.placeholderValue
        ? Schema.success(new PlaceholderSecretToken())
        : Schema.failure(
            input,
            context,
            `not “${PlaceholderSecretToken.placeholderValue}”: ${value}`,
          );
    })(Schema.string.validate(input, context)),
  (a) => a.uri,
);

export const SecretTokenOrPlaceholder = Schema.union([
  SecretTokenUri,
  Placeholder,
]);

export const Probability = new Schema.Type<number, number, unknown>(
  "Placeholder",
  (u): u is number => typeof u === "number" && u <= 1 && u >= 0,
  (input, context) =>
    Either.chain((value: number): Schema.Validation<number> => {
      if (value < 0) {
        return Schema.failure(input, context, `can't be less than 0: ${value}`);
      } else if (value > 1) {
        return Schema.failure(input, context, `can't be more than 1: ${value}`);
      } else {
        return Schema.success(value);
      }
    })(Schema.number.validate(input, context)),
  (a) => a,
);

export function body<Parsed, Encoded>(
  schema: Schema.Type<Parsed, Encoded>,
  body: unknown,
): Parsed {
  const result = schema.decode(body);
  if (Either.isRight(result)) {
    return result.right;
  } else {
    throw new WebError(
      StatusCodes.BAD_REQUEST,
      `Invalid request:\n${Reporters.report(result).join("\n")}`,
    );
  }
}

export function maybeBody<Parsed, Encoded>(
  schema: Schema.Type<Parsed, Encoded>,
  body: unknown,
): Parsed | undefined {
  const result = schema.decode(body);
  return Either.isRight(result) ? result.right : undefined;
}
export * as Validation from "./validation.js";
