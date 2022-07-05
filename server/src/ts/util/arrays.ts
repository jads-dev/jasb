export const singletonOrArray = <Item>(itemOrItems: Item | Item[]): Item[] =>
  Array.isArray(itemOrItems) ? itemOrItems : [itemOrItems];

export * as Arrays from "./arrays.js";
