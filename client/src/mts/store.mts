import type { InboundPort, OutboundPort } from "../elm/JoeBets.mjs";

export interface Flags {
  store: Value[];
}

export interface Ports {
  storeCmd: InboundPort<Op>;
  storeSub: OutboundPort<Value | StoreError>;
}

type Op = Get | Set | Delete;

interface Get {
  op: "Get";
  key: string;
}

interface Set {
  op: "Set";
  key: string;
  value: unknown;
  schemaVersion: number;
  ifDocumentVersion?: number;
}

interface Delete {
  op: "Delete";
  key: string;
  ifDocumentVersion?: number;
}

interface Item {
  value: unknown;
  schemaVersion: number;
  documentVersion: number;
}

interface Value {
  key: string;
  item?: Item;
}

type StoreError = "PreconditionFailed";

type ReceiveValueCallback = (valueOrError: Value | StoreError) => void;

export interface Store {
  readonly metadata: unknown;
  getAll: () => Iterable<Value>;
  onReceiveValue: (callback: ReceiveValueCallback) => void;
  get: (key: string) => void;
  set: (
    key: string,
    value: unknown,
    schemaVersion: number,
    ifDocumentVersion?: number,
  ) => void;
  delete: (key: string, ifDocumentVersion?: number) => void;
}

export const init = (): Store => {
  if (window.localStorage !== undefined) {
    try {
      return Browser.createOrMigrate(window.localStorage);
    } catch (e) {
      console.warn((e as Error)?.message);
      return new Null();
    }
  } else {
    return new Null();
  }
};

export const flags = (store: Store): Flags => ({
  store: [...store.getAll()],
});

export const ports = (store: Store, ports: Ports): void => {
  store.onReceiveValue((value) => {
    ports.storeSub.send(value);
  });
  ports.storeCmd.subscribe((cmd: Op) => {
    switch (cmd.op) {
      case "Get":
        store.get(cmd.key);
        break;

      case "Set":
        store.set(cmd.key, cmd.value, cmd.schemaVersion, cmd.ifDocumentVersion);
        break;

      case "Delete":
        store.delete(cmd.key, cmd.ifDocumentVersion);
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

interface Metadata<Version = number> {
  version: Version;
}

class Browser implements Store {
  private static readonly metadataKey = "metadata";
  private static readonly currentMetadataVersion = 0;
  private static readonly prefix = `jasb:`;
  private static readonly defaultMetadata: Metadata<
    typeof Browser.currentMetadataVersion
  > = {
    version: Browser.currentMetadataVersion,
  };

  public readonly metadata: Metadata<typeof Browser.currentMetadataVersion>;
  private readonly backend: Storage;
  private callback: ReceiveValueCallback | undefined;

  public static createOrMigrate(backend: Storage): Browser {
    const metadata = Browser.getMetadata(backend);
    return new this(metadata, backend);
  }

  private constructor(
    metadata: Metadata<typeof Browser.currentMetadataVersion>,
    backend: Storage,
  ) {
    this.metadata = metadata;
    this.backend = backend;
    window.addEventListener("storage", (storageEvent: StorageEvent) => {
      if (this.callback !== undefined && storageEvent.key !== null) {
        if (storageEvent.newValue !== null) {
          const item: Item = JSON.parse(storageEvent.newValue);
          const value: Value = {
            key: storageEvent.key.slice(Browser.prefix.length - 1),
            item,
          };
          this.callback(value);
        } else {
          const value: Value = {
            key: storageEvent.key.slice(Browser.prefix.length - 1),
          };
          this.callback(value);
        }
      }
    });
  }

  *getAll(): Iterable<Value> {
    for (const key of this.keys()) {
      const item = this.internalGet(key);
      if (item !== undefined) {
        yield { key, item };
      }
    }
  }

  onReceiveValue(callback: ReceiveValueCallback): void {
    this.callback = callback;
  }

  get(key: string): void {
    if (this.callback !== undefined) {
      const item = this.internalGet(key);
      this.callback({ key, ...(item !== undefined ? { item } : {}) });
    }
  }

  set(
    key: string,
    value: unknown,
    schemaVersion: number,
    ifDocumentVersion?: number,
  ): void {
    const existingItem = this.internalGet(key);
    const existingDocumentVersion = existingItem?.documentVersion ?? -1;

    if (
      ifDocumentVersion === undefined ||
      ifDocumentVersion === existingDocumentVersion
    ) {
      const item = {
        value,
        schemaVersion,
        documentVersion: existingDocumentVersion + 1,
      };

      this.backend.setItem(`${Browser.prefix}${key}`, JSON.stringify(item));
      if (this.callback !== undefined) {
        this.callback({ key, item });
      }
    } else {
      if (this.callback !== undefined) {
        this.callback("PreconditionFailed");
      }
    }
  }

  delete(key: string, ifDocumentVersion?: number): void {
    const existingItem = this.internalGet(key);
    const existingDocumentVersion = existingItem?.documentVersion ?? -1;

    if (
      ifDocumentVersion === undefined ||
      ifDocumentVersion === existingDocumentVersion
    ) {
      this.backend.removeItem(`${Browser.prefix}${key}`);
      if (this.callback !== undefined) {
        this.callback({ key });
      }
    } else {
      if (this.callback !== undefined) {
        this.callback("PreconditionFailed");
      }
    }
  }

  private internalGet(key: string): Item | undefined {
    const rawItem = this.backend.getItem(`${Browser.prefix}${key}`);
    if (rawItem !== null) {
      return JSON.parse(rawItem);
    }
    return undefined;
  }

  private *keys(): Iterable<string> {
    const length = this.backend.length;
    for (let index = 0; index < length; index++) {
      const key = this.backend.key(index);
      if (key !== null && key.startsWith(Browser.prefix)) {
        yield key.slice(Browser.prefix.length);
      }
    }
  }

  private static getMetadata(
    backend: Storage,
  ): Metadata<typeof Browser.currentMetadataVersion> {
    const rawMetadata = backend.getItem(Browser.prefix + Browser.metadataKey);
    if (rawMetadata !== null) {
      const metadata = JSON.parse(rawMetadata);
      return Browser.migrate(metadata);
    } else {
      return Browser.defaultMetadata;
    }
  }

  private static migrate(
    from: Metadata,
  ): Metadata<typeof Browser.currentMetadataVersion> {
    if (from.version === Browser.currentMetadataVersion) {
      return from as Metadata<typeof Browser.currentMetadataVersion>;
    }
    if (from.version >= Browser.currentMetadataVersion) {
      throw new Error("Future metadata found, disabling store.");
    }
    switch (from.version) {
      default:
        console.warn(
          `Unable to update metadata from version ${from.version}. Discarding old store.`,
        );
        return Browser.defaultMetadata;
    }
  }
}

class Null implements Store {
  public readonly metadata = undefined;
  private callback: ReceiveValueCallback | undefined;

  getAll(): Value[] {
    return [];
  }

  onReceiveValue(callback: ReceiveValueCallback): void {
    this.callback = callback;
  }

  set(key: string, value: unknown, schemaVersion: number): void {
    if (this.callback !== undefined) {
      this.callback({
        key,
        item: { value, schemaVersion, documentVersion: -1 },
      });
    }
  }

  delete(key: string): void {
    if (this.callback !== undefined) {
      this.callback({
        key,
      });
    }
  }

  get(key: string): void {
    if (this.callback !== undefined) {
      this.callback({ key });
    }
  }
}
