import * as Joda from "@js-joda/core";

const Uncached: unique symbol = Symbol();
type Uncached = typeof Uncached;

export class ResultCache<T> {
  readonly generate: () => Promise<T>;
  readonly lifespan: Joda.Duration;
  cache: { value: T; expires: Joda.ZonedDateTime } | Uncached;

  constructor(generate: () => Promise<T>, lifespan: Joda.Duration) {
    this.generate = generate;
    this.lifespan = lifespan;
    this.cache = Uncached;
  }

  async get(): Promise<T> {
    if (
      this.cache !== Uncached &&
      this.cache.expires > Joda.ZonedDateTime.now(Joda.ZoneOffset.UTC)
    ) {
      return this.cache.value;
    } else {
      const value = await this.generate();
      this.cache = {
        value,
        expires: Joda.ZonedDateTime.now(Joda.ZoneOffset.UTC).plus(
          this.lifespan
        ),
      };
      return value;
    }
  }
}
