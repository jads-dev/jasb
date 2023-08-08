import * as zlib from "node:zlib";

import { default as HtmlWebpackInjectPreload } from "@principalstudio/html-webpack-inject-preload";
import { default as CompressionPlugin } from "compression-webpack-plugin";
import { default as HtmlWebpackPlugin } from "html-webpack-plugin";
import { default as MiniCssExtractPlugin } from "mini-css-extract-plugin";
import * as sass from "sass";
import { default as TerserPlugin } from "terser-webpack-plugin";

export const generateConfig = (env, argv) => {
  const mode = argv?.mode ?? process.env["WEBPACK_MODE"] ?? "production";

  const production = mode === "production";
  const inDocker = process.env["JASB_DEV_ENV"] === "docker";

  const styleLoaders = [
    // Load CSS to inline styles.
    {
      loader: "css-loader",
      options: { sourceMap: !production },
    },
    // Transform CSS for compatibility.
    {
      loader: "postcss-loader",
      options: {
        sourceMap: !production,
      },
    },
    // Allow relative URLs.
    {
      loader: "resolve-url-loader",
      options: { sourceMap: !production },
    },
    // Load SASS to CSS.
    {
      loader: "sass-loader",
      options: {
        implementation: sass,
        sourceMap: true,
        sassOptions: {
          includePaths: ["node_modules"],
        },
      },
    },
  ];

  return {
    mode,
    entry: {
      index: "./src/mts/index.mts",
    },
    output: {
      publicPath: "/",
      filename: "assets/scripts/[name].[contenthash].mjs",
      clean: true,
    },
    module: {
      rules: [
        // Font assets.
        {
          test: /\.(woff2)$/,
          type: "asset/resource",
          generator: {
            filename: "assets/fonts/[name].[hash][ext]",
          },
        },
        // Image assets.
        {
          test: /\.(png|webp|avif|png|svg)$/,
          type: "asset",
          generator: {
            filename: "assets/images/[name].[hash][ext]",
          },
        },
        // Styles.
        {
          test: /\.s?css$/,
          exclude: [/elm-stuff/, /node_modules/, /components\/.*\.s?css$/],
          use: [
            production
              ? {
                  loader: MiniCssExtractPlugin.loader,
                }
              : { loader: "style-loader" },
            ...styleLoaders,
          ],
        },
        // Elm scripts.
        {
          test: /\.elm$/,
          exclude: [/elm-stuff/, /node_modules/],
          use: [
            {
              loader: "elm-webpack-loader",
              options: {
                optimize: production,
                debug: !production,
              },
            },
          ],
        },
        // Typescript scripts.
        {
          test: /\.[cm]?[tj]s$/,
          exclude: [/elm-stuff/, /node_modules/],
          use: "ts-loader",
        },
        // HTML
        {
          test: /\.html$/,
          loader: "html-loader",
        },
      ],
    },
    stats: {
      children: true,
    },
    resolve: {
      extensions: [".js", ".mjs", ".elm", ".css", ".scss", ".wasm"],
      extensionAlias: {
        ".mjs": [".mjs", ".mts", ".ts", ".elm"],
        ".cjs": [".cjs", ".cts", ".ts", ".elm"],
        ".js": [".js", ".mts", ".cts", ".ts", ".elm"],
      },
      modules: ["node_modules"],
    },
    plugins: [
      new MiniCssExtractPlugin({
        filename: "assets/styles/[name].[contenthash].css",
      }),
      new HtmlWebpackPlugin({
        filename: "index.html",
        template: "./src/html/index.html",
        scriptLoading: "module",
        inject: "body",
      }),
      new HtmlWebpackInjectPreload({
        files: [
          {
            match: /assets\/scripts\/index.*\.js$/,
            attributes: { as: "script" },
          },
          {
            match: /assets\/fonts\/.*\.woff2$/,
            attributes: { as: "font", type: "font/woff2" },
          },
        ],
      }),
      ...(production
        ? [
            new CompressionPlugin({
              test: /\.(mjs|css|html|svg)$/,
              filename: "[path][base].gz",
              algorithm: "gzip",
              minRatio: 0.9,
            }),
            new CompressionPlugin({
              test: /\.(mjs|css|html|svg)$/,
              filename: "[path][base].br",
              algorithm: "brotliCompress",
              compressionOptions: {
                params: {
                  [zlib.constants.BROTLI_PARAM_QUALITY]: 11,
                },
              },
              minRatio: 0.9,
            }),
          ]
        : []),
    ],
    optimization: {
      splitChunks: {
        chunks: "all",
      },
      minimizer: [
        new TerserPlugin({
          test: /assets\/scripts\/.*\.mjs$/,
          exclude: /assets\/scripts\/JoeBets.*\.mjs$/,
          parallel: true,
          extractComments: false,
          terserOptions: {
            output: {
              comments: false,
            },
          },
        }),
        new TerserPlugin({
          test: /assets\/scripts\/JoeBets.*\.mjs$/,
          parallel: true,
          extractComments: false,
          terserOptions: {
            compress: {
              pure_funcs: [
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
              ],
              pure_getters: true,
              keep_fargs: false,
              unsafe_comps: true,
              unsafe: true,
              passes: 2,
            },
            mangle: true,
            output: {
              comments: false,
            },
          },
        }),
      ],
    },
    experiments: {
      outputModule: true,
    },
    devtool: production ? undefined : "source-map",
    devServer: {
      static: [{ directory: "./dist" }],
      hot: true,
      host: inDocker ? "0.0.0.0" : "localhost",
      port: 8080,
      allowedHosts: ["localhost"],
      proxy: {
        // Forward to the server.
        "/api/**": {
          target: inDocker ? "http://server:8081" : "http://localhost:8081",
        },
        // As we are an SPA, this lets us route all requests to the index.
        "**": {
          target: "http://localhost:8080",
          pathRewrite: {
            ".*": "",
          },
        },
      },
    },
  };
};

export default generateConfig;
