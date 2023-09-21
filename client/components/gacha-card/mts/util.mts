export const spaceSeparatedList = {
  fromAttribute: (value: string | null): string[] =>
    value ? value.split(" ") : [],
  toAttribute: (values: string[]): string | null =>
    values.length > 0 ? values.join(" ") : null,
};

export const round = (value: number, precision = 3) =>
  parseFloat(value.toFixed(precision));

export const clamp = (value: number, min: number, max: number) =>
  Math.min(Math.max(value, min), max);

export const rescale = (
  value: number,
  min: number,
  max: number,
  scaledMin: number,
  scaledMax: number,
) => round(scaledMin + ((scaledMax - scaledMin) * (value - min)) / (max - min));

export const roughlyEquals = (
  value: number,
  target: number,
  margin = 2 ** -2,
): boolean => Math.abs(value - target) < margin;
