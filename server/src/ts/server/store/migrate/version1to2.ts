import {
  DocumentReference,
  Firestore,
  Timestamp,
} from "@google-cloud/firestore";

import { V1 } from "../v1";
import { V2 } from "../v2";

export async function version1to2(db: Firestore): Promise<number> {
  const toDelete: DocumentReference[] = [];

  const eventsRef = db.collectionGroup("events");
  const eventDocs = await eventsRef.get();
  for (const eventDoc of eventDocs.docs) {
    toDelete.push(eventDoc.ref);
  }
  const notificationsRef = db.collectionGroup("notifications");
  const notificationDocs = await notificationsRef.get();
  for (const notificationDoc of notificationDocs.docs) {
    toDelete.push(notificationDoc.ref);
  }

  const historicEvents = new Map<string, V2.EventLog.HistoricAccount>();
  const usersRef = db.collection("users");
  const userDocs = await usersRef.get();
  for (const userDoc of userDocs.docs) {
    const user = userDoc.data() as V1.User;
    historicEvents.set(userDoc.id, {
      event: "HistoricAccount",
      balance: user.balance,
      betValue: user.betValue,
    });
  }

  const at = Timestamp.now();

  for (const ref of toDelete) {
    await ref.delete();
  }

  for (const [userId, historicEvent] of historicEvents.entries()) {
    const eventsRef = usersRef.doc(userId).collection("events").doc();
    const event: V2.EventLog.Entry = {
      event: historicEvent,
      at,
    };
    await eventsRef.set(event);
  }

  return 2;
}
