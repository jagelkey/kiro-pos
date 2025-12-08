-- Migration: Add sync_queue table for offline-first sync
-- Created: 2025-12-08

CREATE TABLE IF NOT EXISTS sync_queue (
  id TEXT PRIMARY KEY,
  table_name TEXT NOT NULL,
  operation_type TEXT NOT NULL CHECK(operation_type IN ('insert', 'update', 'delete')),
  data TEXT NOT NULL,
  created_at TEXT NOT NULL,
  retry_count INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_sync_queue_created_at ON sync_queue(created_at);
CREATE INDEX IF NOT EXISTS idx_sync_queue_table ON sync_queue(table_name);
