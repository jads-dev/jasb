import * as Luxon from "luxon";

const Uncached: unique symbol = Symbol();
type Uncached = typeof Uncached;

export class ResultCache<T> {
  readonly generate: () => Promise<T>;
  readonly lifespan: Luxon.Duration;
  cache: { value: T; expires: Luxon.DateTime } | Uncached;

  constructor(generate: () => Promise<T>, lifespan: Luxon.Duration) {
    this.generate = generate;
    this.lifespan = lifespan;
    this.cache = Uncached;
  }

  async get(): Promise<T> {
    if (this.cache !== Uncached && this.cache.expires > Luxon.DateTime.utc()) {
      return this.cache.value;
    } else {
      const value = await this.generate();
      this.cache = { value, expires: Luxon.DateTime.utc().plus(this.lifespan) };
      return value;
    }
  }
}
