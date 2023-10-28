module.exports = {
  root: true,
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["client/tsconfig.json", "server/tsconfig.json"],
    tsconfigRootDir: __dirname,
  },
  plugins: ["@typescript-eslint", "simple-import-sort"],
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/strict-type-checked",
    "plugin:@typescript-eslint/stylistic-type-checked",
  ],
  rules: {
    "simple-import-sort/imports": "error",
    "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
    "@typescript-eslint/no-unsafe-enum-comparison": "off",
    "@typescript-eslint/no-unnecessary-condition": [
      "error",
      { allowConstantLoopConditions: true },
    ],
    "no-restricted-globals": [
      "error",
      {
        name: "Buffer",
        message: "Use Uint8Array instead.",
      },
    ],
    "no-restricted-imports": [
      "error",
      {
        name: "buffer",
        message: "Use Uint8Array instead.",
      },
      {
        name: "node:buffer",
        message: "Use Uint8Array instead.",
      },
    ],
    "@typescript-eslint/ban-types": [
      "error",
      {
        types: {
          Buffer: {
            message: "Use Uint8Array instead.",
            suggest: ["Uint8Array"],
          },
        },
      },
    ],
  },
};
