import { secureRandomString } from "./random.js";

export interface SecretTokenLike {
  value: string;
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
    return `${SecretToken.scheme}${this.value}`;
  }

  public inSecureEnvironment(): void {
    // Do Nothing.
  }

  public static fromUri(uri: string): SecretToken | undefined {
    if (uri.startsWith(SecretToken.scheme)) {
      const value = uri.slice(SecretToken.scheme.length);
      return value.length < 1 ? undefined : SecretToken.fromValue(value);
    } else {
      return undefined;
    }
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
}

export class PlaceholderSecretToken implements SecretTokenLike {
  public static readonly placeholderValue = "CHANGE_ME";

  public get value(): typeof PlaceholderSecretToken.placeholderValue {
    if (process.env.NODE_ENV !== "development") {
      this.inSecureEnvironment();
    }
    return PlaceholderSecretToken.placeholderValue;
  }

  public get uri(): typeof PlaceholderSecretToken.placeholderValue {
    return PlaceholderSecretToken.placeholderValue;
  }

  public inSecureEnvironment(): void {
    throw new Error(
      `Attempted to use placeholder secret token (“${PlaceholderSecretToken.placeholderValue}”) outside development environment.`
    );
  }
}
