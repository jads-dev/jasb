import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";

import { Users } from "../../public/users/core.js";
import { Expect } from "../../util/expect.js";
import { Validation } from "../../util/validation.js";
import { WebError } from "../errors.js";

/**
 * Credentials from the client used to authorize requests against JASB.
 * Note that credentials are not validated when they are created, they are
 * representations of *requests* to be authorized, not approved authorizations.
 * They should *not* be assumed to be valid.
 */

/**
 * The request does not contain any authorization, and should not expose any
 * information that requires authorization.
 * Optionally contains information about why the user is unauthorized, the
 * default assumption being that no attempt to authenticate was made.
 */
export const Unauthorized = Schema.readonly(
  Schema.intersection([
    Schema.strict({
      credential: Schema.literal("unauthorized"),
    }),
    Schema.partial({
      reason: Schema.keyof({
        "expired-session": null,
        "invalid-session": null,
      }),
    }),
  ]),
);
export type Unauthorized = Schema.TypeOf<typeof Unauthorized>;

/**
 * A user session created by the web client, where the user is acting directly
 * on their own behalf.
 */
export const UserSession = Schema.readonly(
  Schema.strict({
    credential: Schema.literal("user-session"),
    user: Users.Slug,
    session: Validation.SecretTokenUri,
  }),
);
export type UserSession = Schema.TypeOf<typeof UserSession>;

/**
 * An external service that is requesting to act on behalf of a user.
 */
export const ExternalService = Schema.readonly(
  Schema.strict({
    credential: Schema.literal("external-service"),
    service: Schema.string,
    actingAs: Users.Slug,
  }),
);
export type ExternalService = Schema.TypeOf<typeof ExternalService>;

/**
 * A credential that has the potential to authorize a specific user for a request.
 */
export const Identifying = Schema.union([UserSession, ExternalService]);
export type Identifying = Schema.TypeOf<typeof Identifying>;

/**
 * A credential of some kind.
 */
export const Credential = Schema.union([Identifying, Unauthorized]);
export type Credential = Schema.TypeOf<typeof Credential>;

export const actingUserIfAuthorized = (
  credential: Credential,
): Users.Slug | undefined => {
  const credentialType = credential.credential;
  switch (credentialType) {
    case "user-session":
      return credential.user;
    case "external-service":
      return credential.actingAs;
    case "unauthorized":
      return undefined;
    default:
      return Expect.exhaustive("credential type")(credentialType);
  }
};

export const actingUser = (credential: Identifying): Users.Slug => {
  const credentialType = credential.credential;
  switch (credentialType) {
    case "user-session":
      return credential.user;
    case "external-service":
      return credential.actingAs;
    default:
      return Expect.exhaustive("credential type")(credentialType);
  }
};

export const ensureCanActAs = (
  credential: Credential,
  requiredUser: Users.Slug,
): void => {
  if (actingUserIfAuthorized(credential) !== requiredUser) {
    throw new WebError(
      StatusCodes.FORBIDDEN,
      "Only the owning user may perform that action.",
    );
  }
};

export * as Credentials from "./credentials.js";
