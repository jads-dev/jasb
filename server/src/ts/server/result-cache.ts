import * as Joda from "@js-joda/core";

const Uncached: unique symbol = Symbol();
type Uncached = typeof Uncached;

export class ResultCache<Context, Value> {
  readonly #generate: (context: Context) => Promise<Value>;
  readonly #lifespan: Joda.Duration;
  #cache: { value: Value; expires: Joda.ZonedDateTime } | Uncached;

  constructor(
    generate: (context: Context) => Promise<Value>,
    lifespan: Joda.Duration,
  ) {
    this.#generate = generate;
    this.#lifespan = lifespan;
    this.#cache = Uncached;
  }

  async get(context: Context): Promise<Value> {
    if (
      this.#cache !== Uncached &&
      this.#cache.expires.isAfter(Joda.ZonedDateTime.now(Joda.ZoneOffset.UTC))
    ) {
      return this.#cache.value;
    } else {
      const value = await this.#generate(context);
      this.#cache = {
        value,
        expires: Joda.ZonedDateTime.now(Joda.ZoneOffset.UTC).plus(
          this.#lifespan,
        ),
      };
      return value;
    }
  }
}
