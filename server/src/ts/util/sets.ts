export const equal = <Value>(a: Set<Value>, b: Set<Value>): boolean => {
  if (a.size === b.size) {
    for (const value of a) {
      if (!b.has(value)) {
        return false;
      }
    }
    return true;
  } else {
    return false;
  }
};

export function* subtract<Value>(
  values: Set<Value>,
  remove: Set<Value>,
): Iterable<Value> {
  for (const value of values) {
    if (!remove.has(value)) {
      yield value;
    }
  }
}

export * as Sets from "./sets.js";
