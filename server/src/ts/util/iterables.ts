export function* zip<Items extends unknown[]>(
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
}

export function partition<Item>(
  predicate: (item: Item) => boolean,
  items: Item[]
): [Item[], Item[]] {
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
}

export * as Iterables from "./iterables";
