import type { InboundPort } from "../elm/Jasb.mjs";

export interface Ports {
  selectCmd: InboundPort<string>;
}

export const ports = ({ selectCmd }: Ports): void => {
  selectCmd.subscribe((id: string) => {
    requestAnimationFrame(() => {
      const element = document.getElementById(id) as { select?: () => {} };
      if (typeof element?.["select"] === "function") {
        element.select();
      }
    });
  });
};
