export const exhaustive = <TValue>(
  description: string,
  property: (v: TValue) => unknown = (v) => v
) => (value: never): never => {
  throw new Error(
    `Unhandled ${description} value: "${property(value as TValue)}".`
  );
};

export * as Expect from "./expect";
