import { SecretToken } from "./util/secret-token.js";

const main = async (): Promise<void> =>
  console.log((await SecretToken.secureRandom(64)).uri);

main().catch((error) => {
  console.log(`Error generating secret: ${error}`);
});
