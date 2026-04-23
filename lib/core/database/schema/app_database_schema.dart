class AppDatabaseSchema {
  const AppDatabaseSchema._();

  static const int version = 1;

  static const List<String> initialStatements = <String>[
    '''
    CREATE TABLE IF NOT EXISTS app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS device_info (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      device_id TEXT NOT NULL,
      platform TEXT NOT NULL,
      registered_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS user_session (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      user_id TEXT NOT NULL,
      user_name TEXT NOT NULL,
      user_email TEXT NOT NULL,
      company_id TEXT NOT NULL,
      company_name TEXT NOT NULL,
      roles_json TEXT NOT NULL,
      access_token_expires_at TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS products_snapshot (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      remote_id TEXT,
      name TEXT NOT NULL,
      category_name TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS product_variants_snapshot (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      remote_id TEXT,
      product_remote_id TEXT,
      barcode TEXT,
      sku TEXT,
      display_name TEXT NOT NULL,
      short_name TEXT,
      color TEXT,
      size TEXT,
      category_name TEXT,
      price_cents INTEGER NOT NULL,
      promotional_price_cents INTEGER,
      image_url TEXT,
      image_local_path TEXT,
      is_active_for_sale INTEGER NOT NULL DEFAULT 1,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS categories_snapshot (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      remote_id TEXT,
      name TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS price_rules_snapshot (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      remote_id TEXT,
      variant_remote_id TEXT NOT NULL,
      price_cents INTEGER NOT NULL,
      promotional_price_cents INTEGER,
      starts_at TEXT,
      ends_at TEXT,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS sales (
      local_id TEXT PRIMARY KEY,
      remote_id TEXT,
      company_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      customer_local_id TEXT,
      customer_remote_id TEXT,
      cash_session_local_id TEXT,
      subtotal_cents INTEGER NOT NULL,
      discount_cents INTEGER NOT NULL DEFAULT 0,
      total_cents INTEGER NOT NULL,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      synced_at TEXT
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS sale_items (
      local_id TEXT PRIMARY KEY,
      sale_local_id TEXT NOT NULL,
      variant_local_id TEXT,
      variant_remote_id TEXT,
      display_name TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      unit_price_cents INTEGER NOT NULL,
      total_price_cents INTEGER NOT NULL,
      discount_cents INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS payments (
      local_id TEXT PRIMARY KEY,
      sale_local_id TEXT NOT NULL,
      method TEXT NOT NULL,
      amount_cents INTEGER NOT NULL,
      change_cents INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS payment_terms (
      local_id TEXT PRIMARY KEY,
      sale_local_id TEXT NOT NULL,
      remote_id TEXT,
      customer_local_id TEXT,
      customer_remote_id TEXT,
      payment_method TEXT NOT NULL,
      original_amount_cents INTEGER NOT NULL,
      paid_amount_cents INTEGER NOT NULL DEFAULT 0,
      outstanding_amount_cents INTEGER NOT NULL,
      due_date TEXT NOT NULL,
      payment_status TEXT NOT NULL,
      notes TEXT,
      sync_status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS receivable_payments (
      local_id TEXT PRIMARY KEY,
      payment_term_local_id TEXT NOT NULL,
      remote_id TEXT,
      amount_cents INTEGER NOT NULL,
      payment_method_used_for_settlement TEXT NOT NULL,
      paid_at TEXT NOT NULL,
      notes TEXT,
      created_by_user_id TEXT NOT NULL,
      cash_session_local_id TEXT NOT NULL,
      created_at TEXT NOT NULL,
      sync_status TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS receipts (
      local_id TEXT PRIMARY KEY,
      sale_local_id TEXT NOT NULL,
      pdf_path TEXT NOT NULL,
      shared_at TEXT,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS quick_customers (
      local_id TEXT PRIMARY KEY,
      remote_id TEXT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      sync_status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS cash_sessions (
      local_id TEXT PRIMARY KEY,
      remote_id TEXT,
      user_id TEXT NOT NULL,
      opening_amount_cents INTEGER NOT NULL,
      status TEXT NOT NULL,
      opened_at TEXT NOT NULL,
      closed_at TEXT
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS cash_movements (
      local_id TEXT PRIMARY KEY,
      remote_id TEXT,
      cash_session_local_id TEXT NOT NULL,
      type TEXT NOT NULL,
      amount_cents INTEGER NOT NULL,
      notes TEXT,
      sync_status TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS sync_outbox (
      operation_id TEXT PRIMARY KEY,
      device_id TEXT NOT NULL,
      company_id TEXT NOT NULL,
      type TEXT NOT NULL,
      entity_local_id TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      status TEXT NOT NULL,
      retries INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS sync_inbox (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      update_type TEXT NOT NULL,
      entity_remote_id TEXT,
      payload_json TEXT NOT NULL,
      received_at TEXT NOT NULL,
      applied_at TEXT
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS sync_cursor (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      cursor_value TEXT,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS sync_conflicts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      operation_id TEXT NOT NULL,
      conflict_type TEXT NOT NULL,
      details_json TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS sync_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      level TEXT NOT NULL,
      message TEXT NOT NULL,
      context_json TEXT,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_variants_snapshot_barcode
    ON product_variants_snapshot(barcode)
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_variants_snapshot_display_name
    ON product_variants_snapshot(display_name)
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_sync_outbox_status
    ON sync_outbox(status)
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_quick_customers_phone
    ON quick_customers(phone)
    ''',
  ];
}
