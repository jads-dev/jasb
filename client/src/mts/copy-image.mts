import { default as DomToImage } from "dom-to-image";

import type { InboundPort } from "../elm/JoeBets.mjs";

export interface Ports {
  copyImageCmd: InboundPort<string>;
}

export const ports = (ports: Ports): void => {
  // eslint-disable-next-line @typescript-eslint/ban-ts-comment
  // @ts-ignore
  const { toBlob, toPng }: DomToImage.DomToImage = DomToImage;
  ports.copyImageCmd.subscribe((id) => {
    const node = document.getElementById(id);
    if (node !== null) {
      if (typeof ClipboardItem !== "undefined") {
        toBlob(node).then((image) => {
          navigator.clipboard.write([
            new ClipboardItem({ [image.type]: image }),
          ]);
        });
      } else {
        toPng(node).then((imageUri) => {
          window.open(imageUri, "_blank");
        });
      }
    }
  });
};
