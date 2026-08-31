-- ==============================================================================
-- VisionGate / Attenda - PostgreSQL 16 Initializer
-- Enables pgvector, text search, and performance extensions
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Set timezone to Asia/Kolkata / UTC as per Indian standard college operations
SET timezone = 'Asia/Kolkata';

-- Grant required permissions
GRANT ALL PRIVILEGES ON DATABASE attenda TO attenda;
