export const zip = function* <Item, Items extends Item[]>(
  ...sources: { [Index in keyof Items]: Iterable<Items[Index]> }
): Iterable<Items> {
  const iterators = sources.map((source) => source[Symbol.iterator]());
  while (true) {
    const results = iterators.map((source) => source.next());
    if (!results.some((result) => result.done)) {
      yield results.map((result) => result.value as Item) as Items;
    } else {
      return;
    }
  }
};

const noGroup: unique symbol = Symbol();
/**
 * Assumes items are sorted in group first already.
 * @param getGroup Get the group.
 * @param items The items to group.
 */
export function* groupBy<Item, Group>(
  getGroup: (item: Item) => Group,
  items: Iterable<Item>,
): Iterable<[Group, readonly Item[]]> {
  let group: typeof noGroup | Group = noGroup;
  let itemsInGroup: Item[] = [];
  for (const item of items) {
    const itemGroup = getGroup(item);
    if (itemGroup !== group) {
      if (itemsInGroup.length > 0 && group !== noGroup) {
        yield [group, itemsInGroup];
        itemsInGroup = [];
      }
      group = itemGroup;
    }
    itemsInGroup.push(item);
  }
  if (itemsInGroup.length > 0 && group !== noGroup) {
    yield [group, itemsInGroup];
  }
}

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

export * as Iterables from "./iterables.js";
