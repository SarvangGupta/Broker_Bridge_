import { openDB } from 'idb';

const DB_NAME = 'BrokerBridgeDB';
const STORE_NAME = 'offlineRequirements';
const DB_VERSION = 1;

export async function initDB() {
  return openDB(DB_NAME, DB_VERSION, {
    upgrade(db) {
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: 'id', autoIncrement: true });
      }
    },
  });
}

export async function saveRequirementOffline(data: any) {
  const db = await initDB();
  await db.add(STORE_NAME, data);
}

export async function getOfflineRequirements() {
  const db = await initDB();
  return db.getAll(STORE_NAME);
}

export async function clearOfflineRequirements() {
  const db = await initDB();
  await db.clear(STORE_NAME);
}
