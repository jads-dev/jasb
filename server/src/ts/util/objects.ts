import { Iterables } from "./iterables.js";

export function mapValues<O extends Record<string, V>, V, U>(
  obj: O,
  f: (value: V) => U,
): { [P in keyof O]: U } {
  const newObj: Record<string, U> = {};
  for (const [key, value] of Object.entries(obj)) {
    newObj[key] = f(value);
  }
  return newObj as { [P in keyof O]: U };
}

export async function allPromises<O extends Record<string, V>, V, U>(
  obj: O,
  f: (value: V) => Promise<U>,
): Promise<{ [P in keyof O]: U }> {
  const values = await Promise.all(Object.values(obj).map(f));
  return Object.fromEntries(
    Iterables.zip(Object.keys(obj), values),
  ) as unknown as {
    [P in keyof O]: U;
  };
}

export * as Objects from "./objects.js";
