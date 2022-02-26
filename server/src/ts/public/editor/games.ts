import type { Internal } from "../../internal.js";

export interface EditableGame {
  name: string;
  cover: string;
  igdbId: string;
  started?: string;
  finished?: string;

  version: number;
  added: string;
  modified: string;
}

export const fromInternal = (internal: Internal.Game): EditableGame => ({
  name: internal.name,
  cover: internal.cover,
  igdbId: internal.igdb_id,
  ...(internal.started !== null ? { started: internal.started.toJSON() } : {}),
  ...(internal.finished !== null
    ? { finished: internal.finished.toJSON() }
    : {}),

  version: internal.version,
  added: internal.added.toJSON(),
  modified: internal.modified.toJSON(),
});

export * as Games from "./games.js";
