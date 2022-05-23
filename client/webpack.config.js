/* eslint-disable */

const path = require("path");
const sass = require("sass");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const TerserPlugin = require("terser-webpack-plugin");
const CompressionPlugin = require("compression-webpack-plugin");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");

const src = path.join(__dirname, "src");
const assets = path.join(__dirname, "assets");
const dist = path.join(__dirname, "dist");

module.exports = (env, argv) => {
  const mode =
    argv !== undefined && argv.mode !== undefined
      ? argv.mode
      : process.env["WEBPACK_MODE"] !== undefined
      ? process.env["WEBPACK_MODE"]
      : "production";

  const production = mode === "production";
  const inDocker = process.env["JASB_DEV_ENV"] === "docker";

  return {
    mode: mode,
    context: __dirname,
    entry: {
      jasb: path.join(src, "ts", "index.ts"),
    },
    resolve: {
      extensions: [".ts", ".elm", ".js", ".scss", ".css"],
      modules: ["node_modules"],
    },
    module: {
      rules: [
        {
          test: /\.(svg|png)$/,
          type: "asset/resource",
          generator: {
            filename: "assets/images/[name].[hash][ext]",
          },
        },
        {
          test: /\.[tj]s$/,
          exclude: [/elm-stuff/, /node_modules/],
          use: ["ts-loader"],
        },
        {
          test: /\.s?css$/,
          exclude: [/elm-stuff/, /node_modules/],
          use: [
            ...(production
              ? [
                  {
                    loader: MiniCssExtractPlugin.loader,
                  },
                ]
              : [{ loader: "style-loader" }]),
            {
              loader: "css-loader",
              options: { importLoaders: 3, sourceMap: !production },
            },
            {
              loader: "postcss-loader",
              options: {
                sourceMap: !production,
              },
            },
            {
              loader: "sass-loader",
              options: {
                implementation: sass,
                sourceMap: !production,
                sassOptions: {
                  includePaths: ["node_modules"],
                },
              },
            },
          ],
        },
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
      ],
    },
    output: {
      path: dist,
      publicPath: "/",
      filename: "assets/scripts/[name].[contenthash].js",
      clean: true,
    },
    plugins: [
      new MiniCssExtractPlugin({
        filename: "assets/styles/[name].[contenthash].css",
      }),
      new HtmlWebpackPlugin({
        template: "src/html/index.html",
        filename: "index.html",
        inject: "body",
        test: /\.html$/,
      }),
      ...(production
        ? [
            new CompressionPlugin({
              test: /\.(js|css|html|webmanifest|svg)$/,
            }),
          ]
        : []),
    ],
    optimization: {
      minimizer: [
        new TerserPlugin({
          test: /assets\/scripts\/.*\.js$/,
          parallel: true,
          terserOptions: {
            output: {
              comments: false,
            },
          },
        }),
      ],
    },
    devtool: !production ? "eval-source-map" : undefined,
    devServer: {
      static: [{ directory: dist }],
      hot: true,
      host: inDocker ? "0.0.0.0" : "localhost",
      port: 8080,
      allowedHosts: ["localhost"],
      proxy: {
        // Forward to the server.
        "/api/**": {
          target: inDocker ? "http://server:8081" : "http://localhost:8081",
          ws: true,
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
