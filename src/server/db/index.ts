import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from './schema';

const globalForDb = globalThis as unknown as {
  conn: postgres.Sql | undefined;
};

// Optimized Connection Pool for Supabase Transaction Pooler (Port 6543)
const conn =
  globalForDb.conn ??
  postgres(process.env.DATABASE_URL!, {
    prepare: false, // Transaction mode requirement for Supavisor/pgBouncer
    connect_timeout: 30, // 30s timeout to survive transient DNS/network spikes
    idle_timeout: 10, // Recycle idle sockets quickly (10s) to prevent broken pooler handles
    max_lifetime: 60 * 5, // 5 minutes max connection lifetime
    max: 20, // Max concurrent connections
    onnotice: () => {}, // Suppress non-critical DB notices
  });

if (process.env.NODE_ENV !== 'production') globalForDb.conn = conn;

export const db = drizzle(conn, { schema });
