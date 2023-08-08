import type { InboundPort, OutboundPort } from "../elm/JoeBets.mjs";

type Op = Get | Set | Delete;

interface Get {
  op: "Get";
  key: string;
}

interface Set {
  op: "Set";
  key: string;
  value: unknown;
}

interface Delete {
  op: "Delete";
  key: string;
}

interface Value {
  key: string;
  value?: unknown;
}

export interface Ports {
  sessionStoreCmd: InboundPort<Op>;
  sessionStoreSub: OutboundPort<Value>;
}

type ReceiveValueCallback = (value: Value) => void;

export interface Store {
  onReceiveValue: (callback: ReceiveValueCallback) => void;
  get: (key: string) => void;
  set: (key: string, value: unknown) => void;
  delete: (key: string) => void;
}

export const init = (): Store => {
  if (window.sessionStorage !== undefined) {
    return new Browser(sessionStorage);
  } else {
    return new Null();
  }
};

export const ports = (store: Store, ports: Ports): void => {
  store.onReceiveValue((value) => {
    ports.sessionStoreSub.send(value);
  });
  ports.sessionStoreCmd.subscribe((cmd: Op) => {
    switch (cmd.op) {
      case "Get":
        store.get(cmd.key);
        break;

      case "Set":
        store.set(cmd.key, cmd.value);
        break;

      case "Delete":
        store.delete(cmd.key);
        break;

      default:
        console.warn(
          `Unknown operation received through port: “${JSON.stringify(
            cmd,
            undefined,
            2,
          )}”.`,
        );
        break;
    }
  });
};

class Browser implements Store {
  private static readonly prefix = `jasb:`;

  private readonly backend: Storage;
  private callback: ReceiveValueCallback | undefined;

  public constructor(backend: Storage) {
    this.backend = backend;
  }

  onReceiveValue(callback: ReceiveValueCallback): void {
    this.callback = callback;
  }

  private internalGet(key: string): unknown | undefined {
    const rawItem = this.backend.getItem(`${Browser.prefix}${key}`);
    if (rawItem !== null) {
      return JSON.parse(rawItem);
    }
    return undefined;
  }

  get(key: string): void {
    if (this.callback !== undefined) {
      this.callback({ key, value: this.internalGet(key) });
    }
  }

  set(key: string, value: unknown): void {
    this.backend.setItem(`${Browser.prefix}${key}`, JSON.stringify(value));
  }

  delete(key: string): void {
    this.backend.removeItem(`${Browser.prefix}${key}`);
  }
}

class Null implements Store {
  private callback: ReceiveValueCallback | undefined;

  getAll(): Value[] {
    return [];
  }

  onReceiveValue(callback: ReceiveValueCallback): void {
    this.callback = callback;
  }

  set(): void {
    // Do nothing.
  }

  delete(): void {
    // Do nothing.
  }

  get(key: string): void {
    if (this.callback !== undefined) {
      this.callback({ key, value: undefined });
    }
  }
}
