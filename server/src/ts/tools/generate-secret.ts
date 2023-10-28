import { SecretToken } from "../util/secret-token.js";

console.log(SecretToken.secureRandom(64).uri);
