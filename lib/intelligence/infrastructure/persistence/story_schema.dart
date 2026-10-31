/// Centralized DDL definitions for the Atlas Story Memory database tables.
class StorySchema {
  const StorySchema._();

  /// SQL statements to create all Story Memory tables, indexes, and virtual tables.
  static const List<String> createStatements = [
    '''
    CREATE TABLE IF NOT EXISTS story_read_throughs (
      id TEXT NOT NULL,
      book_id TEXT NOT NULL,
      name TEXT NOT NULL,
      current_chapter INTEGER NOT NULL DEFAULT 1,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (book_id, id)
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_story_read_throughs_book ON story_read_throughs(book_id);',

    '''
    CREATE TABLE IF NOT EXISTS story_entities (
      id TEXT NOT NULL PRIMARY KEY,
      book_id TEXT NOT NULL,
      read_through_id TEXT NOT NULL DEFAULT 'default',
      type TEXT NOT NULL,
      canonical_name TEXT NOT NULL,
      aliases TEXT,
      confidence_score REAL NOT NULL,
      tier TEXT NOT NULL,
      user_confirmed INTEGER NOT NULL DEFAULT 0,
      attributes TEXT,
      first_seen_chapter INTEGER NOT NULL DEFAULT 1,
      last_seen_chapter INTEGER NOT NULL DEFAULT 1,
      mention_count INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_story_entities_book ON story_entities(book_id);',
    'CREATE INDEX IF NOT EXISTS idx_story_entities_book_rt ON story_entities(book_id, read_through_id);',
    'CREATE INDEX IF NOT EXISTS idx_story_entities_name ON story_entities(book_id, canonical_name);',
    'CREATE INDEX IF NOT EXISTS idx_story_entities_name_rt ON story_entities(book_id, read_through_id, canonical_name);',

    '''
    CREATE TABLE IF NOT EXISTS story_relationships (
      id TEXT NOT NULL PRIMARY KEY,
      book_id TEXT NOT NULL,
      read_through_id TEXT NOT NULL DEFAULT 'default',
      source_entity_id TEXT NOT NULL,
      target_entity_id TEXT NOT NULL,
      relation_type TEXT NOT NULL,
      confidence_score REAL NOT NULL,
      chapter_established INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_story_rel_book ON story_relationships(book_id);',
    'CREATE INDEX IF NOT EXISTS idx_story_rel_book_rt ON story_relationships(book_id, read_through_id);',
    'CREATE INDEX IF NOT EXISTS idx_story_rel_source ON story_relationships(source_entity_id);',
    'CREATE INDEX IF NOT EXISTS idx_story_rel_target ON story_relationships(target_entity_id);',

    '''
    CREATE TABLE IF NOT EXISTS story_events (
      id TEXT NOT NULL PRIMARY KEY,
      book_id TEXT NOT NULL,
      read_through_id TEXT NOT NULL DEFAULT 'default',
      chapter INTEGER NOT NULL,
      summary TEXT NOT NULL,
      involved_entity_ids TEXT,
      confidence_score REAL NOT NULL,
      created_at INTEGER NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_story_events_book_ch ON story_events(book_id, chapter);',
    'CREATE INDEX IF NOT EXISTS idx_story_events_book_rt_ch ON story_events(book_id, read_through_id, chapter);',

    '''
    CREATE TABLE IF NOT EXISTS story_cooccurrences (
      id TEXT NOT NULL PRIMARY KEY,
      book_id TEXT NOT NULL,
      read_through_id TEXT NOT NULL DEFAULT 'default',
      entity_a_id TEXT NOT NULL,
      entity_b_id TEXT NOT NULL,
      weight INTEGER NOT NULL DEFAULT 1,
      last_seen_chapter INTEGER NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_story_cooccur_book ON story_cooccurrences(book_id);',
    'CREATE INDEX IF NOT EXISTS idx_story_cooccur_book_rt ON story_cooccurrences(book_id, read_through_id);',

    '''
    CREATE TABLE IF NOT EXISTS story_review_queue (
      id TEXT NOT NULL PRIMARY KEY,
      book_id TEXT NOT NULL,
      read_through_id TEXT NOT NULL DEFAULT 'default',
      type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      target_entity_id TEXT,
      candidate_name TEXT NOT NULL,
      target_name TEXT,
      confidence_score REAL NOT NULL,
      similarity_score REAL,
      cooccurrence_count INTEGER NOT NULL DEFAULT 0,
      evidence_json TEXT,
      status TEXT NOT NULL DEFAULT 'pending',
      chapter_index INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_story_review_book_status ON story_review_queue(book_id, status);',
    'CREATE INDEX IF NOT EXISTS idx_story_review_book_rt_status ON story_review_queue(book_id, read_through_id, status);',

    '''
    CREATE TABLE IF NOT EXISTS story_corrections (
      id TEXT NOT NULL PRIMARY KEY,
      book_id TEXT NOT NULL,
      read_through_id TEXT NOT NULL DEFAULT 'default',
      pattern TEXT NOT NULL,
      decision TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_story_corr_book ON story_corrections(book_id);',
    'CREATE INDEX IF NOT EXISTS idx_story_corr_book_rt ON story_corrections(book_id, read_through_id);',

    '''
    CREATE TABLE IF NOT EXISTS story_ingestion_log (
      book_id TEXT NOT NULL,
      read_through_id TEXT NOT NULL DEFAULT 'default',
      chapter_index INTEGER NOT NULL,
      text_hash TEXT NOT NULL,
      ingested_at INTEGER NOT NULL,
      PRIMARY KEY (book_id, read_through_id, chapter_index)
    );
    ''',

    '''
    CREATE VIRTUAL TABLE IF NOT EXISTS story_scenes_fts USING fts5(
      book_id UNINDEXED,
      chapter_index UNINDEXED,
      scene_text,
      tokenize='porter unicode61'
    );
    ''',

    /// Persisted recap snapshots (schema v18, additive): the query-engine
    /// recap for one (book, read-through, reader chapter) so the detail page
    /// renders instantly instead of recomputing the timeline on every open.
    /// Recompute is cheap and overwrites the snapshot for that key.
    '''
    CREATE TABLE IF NOT EXISTS story_recap_snapshots (
      book_id TEXT NOT NULL,
      read_through_id TEXT NOT NULL DEFAULT 'default',
      chapter_index INTEGER NOT NULL,
      recap_text TEXT NOT NULL,
      generated_at INTEGER NOT NULL,
      PRIMARY KEY (book_id, read_through_id, chapter_index)
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_story_recap_book_rt ON story_recap_snapshots(book_id, read_through_id);',

    // Entity-indexed co-occurrence lookups (schema v19, additive index): the
    // extraction pass seeds its graph via getCooccurrencesForEntities, which
    // previously fell back to a (book, read-through) scan.
    'CREATE INDEX IF NOT EXISTS idx_story_cooccur_entities ON story_cooccurrences(entity_a_id, entity_b_id);',
  ];
}

