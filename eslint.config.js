import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  eslint.configs.recommended,
  ...tseslint.configs.strict,
  ...tseslint.configs.stylistic,
  {
    plugins: ["simple-import-sort"],
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
  }
);
