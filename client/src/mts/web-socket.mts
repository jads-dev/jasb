import type { InboundPort, OutboundPort } from "../elm/Jasb.mjs";
import type { BaseUrl } from "./base-url.mjs";

export interface Ports {
  webSocketCmd: InboundPort<string | null>;
  webSocketSub: OutboundPort<string>;
}

export const init = (baseUrl: BaseUrl): Manager => {
  return new Manager(baseUrl);
};

export const ports = (manager: Manager, ports: Ports): void => {
  manager.onReceiveValue((value: string) => {
    ports.webSocketSub.send(value);
  });
  ports.webSocketCmd.subscribe((pathOrNull) => {
    if (pathOrNull === null) {
      manager.disconnect();
    } else {
      manager.connect(pathOrNull);
    }
  });
};

interface SocketWithPath {
  path: string;
  socket: WebSocket;
}

class Manager {
  static readonly #oneSecond = 1000;
  static readonly #oneMinute = Manager.#oneSecond * 60;

  static readonly #initialDelay = Manager.#oneSecond / 2;
  static readonly #maxDelay = Manager.#oneMinute;

  readonly #base: string;
  #socket: SocketWithPath | undefined = undefined;
  #callback: ((value: string) => void) | undefined = undefined;
  #delay: number = Manager.#initialDelay;
  #reconnecting: number | undefined;

  constructor(baseUrl: BaseUrl) {
    const protocol = baseUrl.protocol === "http:" ? "ws:" : "wss:";
    this.#base = `${protocol}//${baseUrl.host}${baseUrl.path}/`;
  }

  onReceiveValue(callback: (value: string) => void): void {
    this.#callback = callback;
  }

  #tryConnect(path: string) {
    const socket = new WebSocket(`${this.#base}${path}`);
    this.#socket = { path, socket };
    socket.addEventListener("open", () => {
      if (this.#socket?.path == path) {
        this.#delay = Manager.#initialDelay;
      }
    });
    socket.addEventListener("message", (event: MessageEvent<string>) => {
      if (this.#callback !== undefined) {
        this.#callback(event.data);
      }
    });
    socket.addEventListener("close", () => {
      this.#reconnectAfterDelay(path);
    });
  }

  #reconnectAfterDelay(path: string) {
    if (this.#reconnecting === undefined) {
      this.#reconnecting = setTimeout(() => {
        if (this.#socket?.path == path) {
          this.#tryConnect(path);
          this.#delay = Math.min(Manager.#maxDelay, this.#delay * 2);
        }
      }, this.#delay);
    }
  }

  connect(path: string) {
    if (this.#socket === undefined || this.#socket.path !== path) {
      if (this.#socket !== undefined) {
        this.#socket.socket.close();
      }
      this.#tryConnect(path);
    }
  }

  disconnect() {
    if (this.#socket !== undefined) {
      const { socket } = this.#socket;
      this.#socket = undefined;
      socket.close();
    }
  }
}
