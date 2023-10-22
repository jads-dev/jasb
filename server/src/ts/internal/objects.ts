import { z } from "zod";

export const Object = z
  .object({
    id: z.number(),
    name: z.string().nullable(),
    url: z.string(),
    source_url: z.string().nullable(),
  })
  .strict();
export type Object = z.infer<typeof Object>;

export * as Objects from "./objects.js";
