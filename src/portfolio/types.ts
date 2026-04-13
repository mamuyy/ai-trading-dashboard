export interface DataQuality {
  verified: boolean;
  baseline_only: boolean;
  missing_avg_cost: boolean;
  provisional_pnl: boolean;
}

export interface Account {
  id: string;
  name: string;
  type: string;
  broker: string;
  baseCurrency: string;
  isActive: boolean;
}

export interface CashBalance {
  accountId: string;
  asOf: string;
  currency: string;
  availableAmount: number;
  settledAmount: number;
  pendingAmount: number;
  dataQuality: DataQuality;
}

export interface Holding {
  accountId: string;
  asOf: string;
  symbol: string;
  assetClass: string;
  quantity: number;
  averageCost?: number;
  marketPrice?: number;
  marketValue?: number;
  dataQuality: DataQuality;
}

export interface AccountTotals {
  accountId: string;
  asOf: string;
  cashValue: number;
  holdingsValue: number;
  totalValue: number;
  provisionalPnl?: number;
  dataQuality: DataQuality;
}

export interface PortfolioSnapshot {
  accounts: Account[];
  cashBalances: CashBalance[];
  holdings: Holding[];
  accountTotals: AccountTotals[];
}

/**
 * Existing card UI contract remains unchanged (same card fields);
 * we only enrich values from portfolio snapshot data.
 */
export interface DashboardAccountCard {
  id: string;
  accountId: string;
  title: string;
  subtitle?: string;
  totalValue?: number;
  cashValue?: number;
  holdingsValue?: number;
  provisionalPnl?: number;
  dataQuality?: DataQuality;
}
