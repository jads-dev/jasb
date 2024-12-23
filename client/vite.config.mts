import * as process from "node:process";

import "dotenv/config";
import { type Plugin, defineConfig, ProxyOptions } from "vite";
import { plugin as elm } from "vite-plugin-elm";
import { compression } from "vite-plugin-compression2";

const production = process.env["NODE_ENV"] !== "development";
const inDocker = process.env["JASB_DEV_ENV"] === "docker";
const server =
  (process.env["JASB_SERVER"] ?? inDocker)
    ? "http://server:8081"
    : "http://localhost:8081";
const stringPort = process.env["JASB_PORT"];
const port = stringPort ? parseInt(stringPort) : 8080;
const url =
  process.env["JASB_URL"] ??
  (production ? "https://bets.jads.stream/" : `http://localhost:${port}/`);
const version = process.env["JASB_VERSION"] ?? "dev";
const objectUpstreamUrl = process.env["JASB_OBJECT_UPSTREAM_URL"] ?? "";

const objectRedirect: Record<string, ProxyOptions> =
  objectUpstreamUrl !== ""
    ? {
        "/assets/objects/": {
          target: objectUpstreamUrl,
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/assets\/objects/, ""),
        },
      }
    : {};

const elmPureFunctions = [
  "F2",
  "F3",
  "F4",
  "F5",
  "F6",
  "F7",
  "F8",
  "F9",
  "A2",
  "A3",
  "A4",
  "A5",
  "A6",
  "A7",
  "A8",
  "A9",
];

const compressionShared = {
  skipIfLargerOrEqual: true,
  include: [/\.css$/, /\.html$/, /\.js$/, /\.mjs$/, /\.svg$/],
};

const spaRedirect = (): Plugin => ({
  name: "spa-redirect",
  configureServer: (server) => {
    server.middlewares.use((req, _res, next): void => {
      const { pathname, search } = new URL(
        req.url ?? "/",
        "http://example.com",
      );
      const [_, firstPart, ..._rest] = pathname.split("/");
      if (
        // API calls should go through.
        firstPart !== "api" &&
        // Assets and source files should go through.
        firstPart !== "assets" &&
        firstPart !== "src" &&
        firstPart !== "components" &&
        firstPart !== "elm-material" &&
        firstPart !== "node_modules" &&
        // Vite APIs should go through.
        !firstPart.startsWith("_") &&
        !firstPart.startsWith("@")
      ) {
        req.url = `/${search}`;
      }
      next();
    });
  },
});

export default defineConfig({
  appType: "spa",
  mode: production ? "production" : "development",
  base: "/",
  define: {
    "import.meta.env.JASB_URL": JSON.stringify(
      url.endsWith("/") ? url : `${url}/`,
    ),
    "import.meta.env.JASB_VERSION": JSON.stringify(version),
  },
  resolve: {
    alias: {
      "../elm/Jasb.mjs": "../elm/Jasb.elm",
    },
  },
  build: {
    assetsInlineLimit: 4096,
  },
  esbuild: {
    pure: elmPureFunctions,
    legalComments: "none",
  },
  server: {
    host: inDocker ? "0.0.0.0" : "localhost",
    port: port,
    strictPort: true,
    proxy: {
      "/api": {
        target: server,
        ws: true,
      },
      ...objectRedirect,
    },
  },
  plugins: [
    spaRedirect(),
    elm(),
    compression({ ...compressionShared }),
    compression({
      ...compressionShared,
      algorithm: "brotliCompress",
      exclude: [/\.gz$/],
    }),
  ],
});
