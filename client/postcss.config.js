import { default as presetEnv } from "postcss-preset-env";
import { default as cssnano } from "cssnano";

export default {
  plugins: [presetEnv, cssnano],
};
