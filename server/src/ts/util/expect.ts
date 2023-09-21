export const exhaustive =
  <TValue>(
    description: string,
    property: (v: TValue) => string = (v) => JSON.stringify(v),
  ) =>
  (value: never): never => {
    throw new Error(
      `Unhandled ${description} value: "${property(value as TValue)}".`,
    );
  };

export * as Expect from "./expect.js";
