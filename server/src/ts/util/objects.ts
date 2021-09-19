import { Iterables } from "./iterables";

export function mapValues<O extends { [key: string]: V }, V, U>(
  obj: O,
  f: (value: V) => U
): { [P in keyof O]: U } {
  const newObj: { [key: string]: U } = {};
  for (const [key, value] of Object.entries(obj)) {
    newObj[key] = f(value);
  }
  return newObj as { [P in keyof O]: U };
}

export async function allPromises<O extends { [key: string]: V }, V, U>(
  obj: O,
  f: (value: V) => Promise<U>
): Promise<{ [P in keyof O]: U }> {
  const values = await Promise.all(Object.values(obj).map(f));
  return Object.fromEntries(Iterables.zip(Object.keys(obj), values)) as {
    [P in keyof O]: U;
  };
}

export * as Objects from "./objects";
