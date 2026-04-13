import {
  AccountTotals,
  DashboardAccountCard,
  DataQuality,
  Holding,
  PortfolioSnapshot,
} from './types';

const DEFAULT_QUALITY: DataQuality = {
  verified: false,
  baseline_only: true,
  missing_avg_cost: true,
  provisional_pnl: true,
};

function mergeQuality(...qualities: Array<DataQuality | undefined>): DataQuality {
  return qualities.reduce<DataQuality>(
    (acc, current) => {
      if (!current) return acc;
      return {
        verified: acc.verified && current.verified,
        baseline_only: acc.baseline_only || current.baseline_only,
        missing_avg_cost: acc.missing_avg_cost || current.missing_avg_cost,
        provisional_pnl: acc.provisional_pnl || current.provisional_pnl,
      };
    },
    { ...DEFAULT_QUALITY, verified: true, baseline_only: false, missing_avg_cost: false, provisional_pnl: false },
  );
}

function computeHoldingValue(holding: Holding): number {
  if (typeof holding.marketValue === 'number') return holding.marketValue;
  if (typeof holding.marketPrice === 'number') return holding.marketPrice * holding.quantity;
  return 0;
}

function totalsByAccount(snapshot: PortfolioSnapshot): Map<string, AccountTotals> {
  const totals = new Map(snapshot.accountTotals.map((total) => [total.accountId, total]));

  if (totals.size > 0) return totals;

  const groupedHoldings = new Map<string, Holding[]>();
  for (const holding of snapshot.holdings) {
    const existing = groupedHoldings.get(holding.accountId) ?? [];
    existing.push(holding);
    groupedHoldings.set(holding.accountId, existing);
  }

  for (const account of snapshot.accounts) {
    const cash = snapshot.cashBalances
      .filter((balance) => balance.accountId === account.id)
      .sort((a, b) => new Date(b.asOf).getTime() - new Date(a.asOf).getTime())[0];

    const holdings = groupedHoldings.get(account.id) ?? [];
    const holdingsValue = holdings.reduce((sum, holding) => sum + computeHoldingValue(holding), 0);
    const cashValue = cash?.availableAmount ?? 0;

    totals.set(account.id, {
      accountId: account.id,
      asOf: cash?.asOf ?? holdings[0]?.asOf ?? new Date(0).toISOString(),
      cashValue,
      holdingsValue,
      totalValue: cashValue + holdingsValue,
      provisionalPnl: undefined,
      dataQuality: mergeQuality(
        cash?.dataQuality,
        ...holdings.map((holding) => holding.dataQuality),
      ),
    });
  }

  return totals;
}

export function connectAccountCardsToPortfolio(
  existingCards: DashboardAccountCard[],
  snapshot: PortfolioSnapshot,
): DashboardAccountCard[] {
  const totals = totalsByAccount(snapshot);

  return existingCards.map((card) => {
    const total = totals.get(card.accountId);

    if (!total) {
      return {
        ...card,
        totalValue: 0,
        cashValue: 0,
        holdingsValue: 0,
        provisionalPnl: 0,
        dataQuality: { ...DEFAULT_QUALITY },
      };
    }

    return {
      ...card,
      totalValue: total.totalValue,
      cashValue: total.cashValue,
      holdingsValue: total.holdingsValue,
      provisionalPnl: total.provisionalPnl,
      dataQuality: total.dataQuality,
    };
  });
}
