import { default as presetEnv } from "postcss-preset-env";
import { default as cssnano } from "cssnano";
import { default as nesting } from "postcss-nesting";

export default {
  plugins: [nesting, presetEnv, cssnano],
};
