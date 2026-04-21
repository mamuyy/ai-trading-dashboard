# ai-trading-dashboard

## First safe step implemented

This repository now includes the first integration-safe milestone for account cards:

- internal portfolio schema for `accounts`, `cash_balances`, `holdings`, and `account_totals`
- explicit data quality fields:
  - `verified`
  - `baseline_only`
  - `missing_avg_cost`
  - `provisional_pnl`
- clear mapping layer from portfolio snapshot data to existing dashboard account cards
- sample portfolio + card data so mapped cards show non-zero values when data exists
- no TradingView webhook implementation
- no Grok live API integration
- UI contract kept unchanged (mapping only enriches existing card objects)

## Files

- `db/schema.sql` — PostgreSQL schema additions
- `src/portfolio/types.ts` — typed snapshot models and unchanged card contract
- `src/portfolio/connectAccountCards.ts` — pure mapping logic from snapshot totals to cards
- `src/portfolio/sampleData.ts` — internal sample snapshot + sample cards
- `src/portfolio/getDashboardAccountCards.ts` — mapping-layer entry point for dashboard loaders
- `src/portfolio/index.ts` — exports

## Next safe step

Wire `mapPortfolioSnapshotToDashboardCards` into the existing dashboard data loader/repository that currently feeds account cards, replacing static `Rp 0` defaults with DB-backed snapshot reads from the new schema. Continue to avoid live TradingView/Grok integrations until this internal read path is stable.
