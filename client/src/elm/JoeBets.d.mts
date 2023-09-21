import type * as SessionStore from "../mts/session-store.mjs";
import type * as Store from "../mts/store.mjs";
import type * as WebSocket from "../mts/web-socket.mjs";

export interface InboundPort<T> {
  subscribe(callback: (data: T) => void): void;
}

export interface OutboundPort<T> {
  send(data: T): void;
}

type flags = Store.Flags & {
  base: string;
};

export namespace Elm {
  export namespace JoeBets {
    export interface App {
      ports: Store.Ports & SessionStore.Ports & WebSocket.Ports;
    }
    export function init(options: {
      node?: HTMLElement | null;
      flags: Flags;
    }): Elm.JoeBets.App;
  }
}
