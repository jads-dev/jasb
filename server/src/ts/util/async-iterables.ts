export async function toArray<Value>(
  iterable: AsyncIterable<Value>
): Promise<Value[]> {
  const result: Value[] = [];
  for await (const value of iterable) {
    result.push(value);
  }
  return result;
}

export async function mapToArray<From, To>(
  iterable: AsyncIterable<From>,
  f: (value: From) => To
): Promise<To[]> {
  const result: To[] = [];
  for await (const value of iterable) {
    result.push(f(value));
  }
  return result;
}

export * as AsyncIterables from "./async-iterables.js";
