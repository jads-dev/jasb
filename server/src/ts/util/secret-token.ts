import * as Util from "util";

import { randomBytes, secureRandomString } from "./random.js";

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

  public static async secureRandom(bytes: number): Promise<SecretToken> {
    return SecretToken.fromValue(await secureRandomString(bytes));
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

export class BufferSecretToken implements SecretTokenLike<Buffer> {
  public static readonly encoding = "base64url";
  public readonly value: Buffer;

  private constructor(value: Buffer) {
    this.value = value;
  }

  public get uri(): string {
    return `${SecretToken.scheme}${this.value.toString(
      BufferSecretToken.encoding,
    )}`;
  }

  public inSecureEnvironment(): void {
    // Do Nothing.
  }

  public static fromUri(uri: string): BufferSecretToken | undefined {
    const value = internalExtractFromUri(uri);
    try {
      return value !== undefined
        ? BufferSecretToken.fromValue(
            Buffer.from(value, BufferSecretToken.encoding),
          )
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

  public static fromValue(value: Buffer): BufferSecretToken {
    if (value.length < 1) {
      throw new Error("Empty secrets are not allowed.");
    }
    return new this(value);
  }

  public static async secureRandom(bytes: number): Promise<BufferSecretToken> {
    return BufferSecretToken.fromValue(await randomBytes(bytes));
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

export class PlaceholderBufferSecretToken implements SecretTokenLike<Buffer> {
  public get value(): Buffer {
    if (process.env["NODE_ENV"] !== "development") {
      this.inSecureEnvironment();
    }
    return Buffer.alloc(64);
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
