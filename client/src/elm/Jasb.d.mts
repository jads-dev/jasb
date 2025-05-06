import type * as SessionStore from "../mts/session-store.mjs";
import type * as Store from "../mts/store.mjs";
import type * as WebSocket from "../mts/web-socket.mjs";
import type * as Select from "../mts/select.mjs";
import type * as Scroll from "../mts/scroll.mjs";

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
  export namespace Jasb {
    export interface App {
      ports: Store.Ports &
        SessionStore.Ports &
        WebSocket.Ports &
        Select.Ports &
        Scroll.Ports;
    }
    export function init(options: {
      node?: HTMLElement | null;
      flags: Flags;
    }): Elm.Jasb.App;
  }
}
