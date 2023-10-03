import * as Path from "node:path";

import { defineConfig } from 'vite'

export default defineConfig({
  build: {
    lib: {
      entry: Path.resolve(__dirname, "mts/gacha-card.mts"),
      name: "GachaCard",
      fileName: "gacha-card"
    }
  }
})