export const singletonOrArray = <Item>(itemOrItems: Item | Item[]): Item[] =>
  Array.isArray(itemOrItems) ? itemOrItems : [itemOrItems];

export const shortest = <Value extends { length: number }>(
  values: readonly Value[],
): Value | undefined => {
  let shortest: Value | undefined = undefined;
  for (const value of values) {
    if (value.length < (shortest?.length ?? Number.MAX_VALUE)) {
      shortest = value;
    }
  }
  return shortest;
};

export * as Arrays from "./arrays.js";
