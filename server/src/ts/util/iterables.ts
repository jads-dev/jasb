export const zip = function* <Items extends unknown[]>(
  ...sources: { [Index in keyof Items]: Iterable<Items[Index]> }
): Iterable<Items> {
  const iterators = sources.map((source) => source[Symbol.iterator]());
  while (true) {
    const results = iterators.map((source) => source.next());
    if (!results.some((result) => result.done)) {
      yield results.map((result) => result.value) as Items;
    } else {
      return;
    }
  }
};

export const partition = <Item>(
  predicate: (item: Item) => boolean,
  items: Item[],
): [Item[], Item[]] => {
  const trues = [];
  const falses = [];
  for (const item of items) {
    if (predicate(item)) {
      trues.push(item);
    } else {
      falses.push(item);
    }
  }
  return [trues, falses];
};

export const filterUndefined = function* <Item>(
  items: Iterable<Item | undefined>,
): Iterable<Item> {
  for (const item of items) {
    if (item !== undefined) {
      yield item;
    }
  }
};

export const map = function* <From, To = From>(
  values: Iterable<From>,
  map: (value: From) => To,
): Iterable<To> {
  for (const value of values) {
    yield map(value);
  }
};

export const interleave = function* <Item>(
  ...sources: Iterable<Item>[]
): Iterable<Item> {
  const iterators = sources.map((source) => source[Symbol.iterator]());
  while (true) {
    for (const result of iterators.map((source) => source.next())) {
      if (!result.done) {
        yield result.value;
      } else {
        return;
      }
    }
  }
};

export * as Iterables from "./iterables";
