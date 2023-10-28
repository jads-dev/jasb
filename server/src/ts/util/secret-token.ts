import * as Util from "util";

import { Base64 } from "./base-64.js";
import { SecureRandom } from "./secure-random.js";

const internalExtractFromUri = (uri: string): string | undefined => {
  if (uri.startsWith(SecretToken.scheme)) {
    const value = uri.slice(SecretToken.scheme.length);
    try {
      return value.length < 1 ? undefined : decodeURIComponent(value);
    } catch (error) {
      if (error instanceof URIError) {
        // Not a valid URI encoded string.
        return undefined;
      }
      throw error;
    }
  } else {
    return undefined;
  }
};

export interface SecretTokenLike<Value = string> {
  value: Value;
  uri: string;
  inSecureEnvironment(): void;
}

export class SecretToken implements SecretTokenLike {
  public static readonly scheme = "secret-token:";
  public readonly value: string;

  private constructor(value: string) {
    this.value = value;
  }

  public get uri(): string {
    return `${SecretToken.scheme}${encodeURIComponent(this.value)}`;
  }

  public inSecureEnvironment(): void {
    // Do Nothing.
  }

  public static fromUri(uri: string): SecretToken | undefined {
    const value = internalExtractFromUri(uri);
    return value !== undefined ? SecretToken.fromValue(value) : undefined;
  }

  public static fromValue(value: string): SecretToken {
    if (value.length < 1) {
      throw new Error("Empty secrets are not allowed.");
    }
    return new this(value);
  }

  public static secureRandom(bytes: number): SecretToken {
    return SecretToken.fromValue(SecureRandom.string(bytes));
  }

  public toString(): string {
    return "[Secret Token]";
  }

  public toJSON(): string {
    return this.toString();
  }

  public [Util.inspect.custom](): string {
    return this.toString();
  }
}

export class PlaceholderSecretToken implements SecretTokenLike {
  public static readonly placeholderValue = "CHANGE_ME";

  public get value(): typeof PlaceholderSecretToken.placeholderValue {
    if (process.env["NODE_ENV"] !== "development") {
      this.inSecureEnvironment();
    }
    return PlaceholderSecretToken.placeholderValue;
  }

  public get uri(): typeof PlaceholderSecretToken.placeholderValue {
    return PlaceholderSecretToken.placeholderValue;
  }

  public inSecureEnvironment(): void {
    throw new Error(
      `Attempted to use placeholder secret token (“${PlaceholderSecretToken.placeholderValue}”) outside development environment.`,
    );
  }

  public toString(): string {
    return "[Placeholder Secret Token]";
  }

  public toJSON(): string {
    return this.toString();
  }

  public [Util.inspect.custom](): string {
    return this.toString();
  }
}

export class BufferSecretToken implements SecretTokenLike<Uint8Array> {
  public readonly value: Uint8Array;

  private constructor(value: Uint8Array) {
    this.value = value;
  }

  public get uri(): string {
    return `${SecretToken.scheme}${Base64.encode(this.value, {
      urlSafe: true,
    })}`;
  }

  public inSecureEnvironment(): void {
    // Do Nothing.
  }

  public static fromUri(uri: string): BufferSecretToken | undefined {
    const value = internalExtractFromUri(uri);
    try {
      return value !== undefined
        ? BufferSecretToken.fromValue(Base64.decode(value))
        : undefined;
    } catch (error) {
      // Not a valid encoded buffer.
      if (error instanceof TypeError) {
        return undefined;
      } else {
        throw error;
      }
    }
  }

  public static fromValue(value: Uint8Array): BufferSecretToken {
    if (value.length < 1) {
      throw new Error("Empty secrets are not allowed.");
    }
    return new this(value);
  }

  public static secureRandom(bytes: number): BufferSecretToken {
    return BufferSecretToken.fromValue(SecureRandom.bytes(bytes));
  }

  public toString(): string {
    return "[Buffer Secret Token]";
  }

  public toJSON(): string {
    return this.toString();
  }

  public [Util.inspect.custom](): string {
    return this.toString();
  }
}

export class PlaceholderBufferSecretToken
  implements SecretTokenLike<Uint8Array>
{
  public get value(): Uint8Array {
    if (process.env["NODE_ENV"] !== "development") {
      this.inSecureEnvironment();
    }
    return new Uint8Array(64);
  }

  public get uri(): typeof PlaceholderSecretToken.placeholderValue {
    return PlaceholderSecretToken.placeholderValue;
  }

  public inSecureEnvironment(): void {
    throw new Error(
      `Attempted to use placeholder secret token (“${PlaceholderSecretToken.placeholderValue}”) outside development environment.`,
    );
  }

  public toString(): string {
    return "[Placeholder Buffer Secret Token]";
  }

  public toJSON(): string {
    return this.toString();
  }

  public [Util.inspect.custom](): string {
    return this.toString();
  }
}
