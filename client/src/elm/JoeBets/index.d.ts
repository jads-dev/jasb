import type * as Store from "../../ts/store";

export interface InboundPort<T> {
  subscribe(callback: (data: T) => void): void;
}

export interface OutboundPort<T> {
  send(data: T): void;
}

export namespace Elm {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  namespace JoeBets {
    export interface App {
      // eslint-disable-next-line @typescript-eslint/ban-types
      ports: Store.Ports;
    }
    export function init(options: {
      node?: HTMLElement | null;
      flags: Store.Flags;
    }): Elm.JoeBets.App;
  }
}
