import { Firestore, Transaction } from "@google-cloud/firestore";
import { default as Winston } from "winston";

import { version0to1 } from "./migrate/version0to1";
import { version1to2 } from "./migrate/version1to2";

const currentVersion = 2;

interface Metadata {
  version: number;
}

export async function migrateIfNeeded(
  logger: Winston.Logger,
  db: Firestore
): Promise<void> {
  const dbVersion = db.collection("meta").doc("data");
  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(dbVersion);
    const metaData = doc.data() as Metadata | undefined;
    if (metaData === undefined) {
      await init(db, transaction);
      logger.info(`Created new database at version "v${currentVersion}".`);
      return;
    } else {
      let version = metaData.version;
      if (version > currentVersion) {
        throw new Error(
          `Can't downgrade from "v${version}" to "v${currentVersion}".`
        );
      }
      while (version < currentVersion) {
        const upgradeStep = upgrade(version);
        if (upgradeStep === undefined) {
          throw new Error(`Can't upgrade from "v${version}".`);
        }
        version = await upgradeStep(db);
        transaction.set(dbVersion, { version });
        logger.info(`Migrated to "v${version}".`);
      }
    }
  });
}

function upgrade(
  version: number
): ((db: Firestore) => Promise<number>) | undefined {
  switch (version) {
    case 0:
      return version0to1;
    case 1:
      return version1to2;
    default:
      return undefined;
  }
}

export async function init(
  db: Firestore,
  transaction: Transaction
): Promise<void> {
  const metaData = db.collection("meta").doc("data");
  await transaction.set(metaData, { version: currentVersion });
}
