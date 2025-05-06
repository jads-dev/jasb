import type { InboundPort } from "../elm/Jasb.mjs";

export interface Ports {
  scrollCmd: InboundPort<string>;
}

export const ports = ({ scrollCmd }: Ports): void => {
  scrollCmd.subscribe((id: string) => {
    requestAnimationFrame(() => {
      document.getElementById(id)?.scrollIntoView();
    });
  });
};
