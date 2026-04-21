-- First safe step schema for dashboard portfolio data.
-- Keeps room for future live integrations without implementing them.

CREATE TABLE IF NOT EXISTS accounts (
  id UUID PRIMARY KEY,
  external_account_id TEXT UNIQUE,
  account_name TEXT NOT NULL,
  account_type TEXT NOT NULL,
  broker_name TEXT NOT NULL,
  base_currency CHAR(3) NOT NULL DEFAULT 'USD',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  source_system TEXT NOT NULL DEFAULT 'internal',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cash_balances (
  id UUID PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  as_of TIMESTAMPTZ NOT NULL,
  currency CHAR(3) NOT NULL,
  available_amount NUMERIC(20, 4) NOT NULL DEFAULT 0,
  settled_amount NUMERIC(20, 4) NOT NULL DEFAULT 0,
  pending_amount NUMERIC(20, 4) NOT NULL DEFAULT 0,
  quality_verified BOOLEAN NOT NULL DEFAULT FALSE,
  quality_baseline_only BOOLEAN NOT NULL DEFAULT TRUE,
  quality_missing_avg_cost BOOLEAN NOT NULL DEFAULT FALSE,
  quality_provisional_pnl BOOLEAN NOT NULL DEFAULT FALSE,
  source_system TEXT NOT NULL DEFAULT 'internal',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (account_id, as_of, currency)
);

CREATE TABLE IF NOT EXISTS holdings (
  id UUID PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  as_of TIMESTAMPTZ NOT NULL,
  symbol TEXT NOT NULL,
  asset_class TEXT NOT NULL,
  quantity NUMERIC(24, 10) NOT NULL,
  average_cost NUMERIC(20, 6),
  market_price NUMERIC(20, 6),
  market_value NUMERIC(20, 4),
  cost_basis NUMERIC(20, 4),
  unrealized_pnl NUMERIC(20, 4),
  quality_verified BOOLEAN NOT NULL DEFAULT FALSE,
  quality_baseline_only BOOLEAN NOT NULL DEFAULT TRUE,
  quality_missing_avg_cost BOOLEAN NOT NULL DEFAULT FALSE,
  quality_provisional_pnl BOOLEAN NOT NULL DEFAULT FALSE,
  source_system TEXT NOT NULL DEFAULT 'internal',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (account_id, as_of, symbol)
);

CREATE TABLE IF NOT EXISTS account_totals (
  id UUID PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  as_of TIMESTAMPTZ NOT NULL,
  cash_value NUMERIC(20, 4) NOT NULL DEFAULT 0,
  holdings_value NUMERIC(20, 4) NOT NULL DEFAULT 0,
  total_value NUMERIC(20, 4) NOT NULL DEFAULT 0,
  provisional_pnl NUMERIC(20, 4),
  quality_verified BOOLEAN NOT NULL DEFAULT FALSE,
  quality_baseline_only BOOLEAN NOT NULL DEFAULT TRUE,
  quality_missing_avg_cost BOOLEAN NOT NULL DEFAULT FALSE,
  quality_provisional_pnl BOOLEAN NOT NULL DEFAULT FALSE,
  source_system TEXT NOT NULL DEFAULT 'internal',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (account_id, as_of)
);

CREATE INDEX IF NOT EXISTS idx_cash_balances_account_as_of
  ON cash_balances (account_id, as_of DESC);

CREATE INDEX IF NOT EXISTS idx_holdings_account_as_of
  ON holdings (account_id, as_of DESC);

CREATE INDEX IF NOT EXISTS idx_holdings_symbol_as_of
  ON holdings (symbol, as_of DESC);

CREATE INDEX IF NOT EXISTS idx_account_totals_account_as_of
  ON account_totals (account_id, as_of DESC);
