import type * as SessionStore from "../ts/session-store.mjs";
import type * as Store from "../ts/store.mjs";

export interface InboundPort<T> {
  subscribe(callback: (data: T) => void): void;
}

export interface OutboundPort<T> {
  send(data: T): void;
}

export namespace Elm {
  export namespace JoeBets {
    export interface App {
      ports: Store.Ports & SessionStore.Ports;
    }
    export function init(options: {
      node?: HTMLElement | null;
      flags: Store.Flags;
    }): Elm.JoeBets.App;
  }
}
