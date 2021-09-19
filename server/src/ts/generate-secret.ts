import { SecretToken } from "./util/secret-token";

const main = async (): Promise<void> =>
  console.log((await SecretToken.secureRandom(64)).uri);

main().catch((error) => {
  console.log(`Error generating secret: ${error}`);
});
