import { DashboardAccountCard, PortfolioSnapshot } from './types';

export const samplePortfolioSnapshot: PortfolioSnapshot = {
  accounts: [
    {
      id: 'acc-growth-1',
      name: 'Growth Account',
      type: 'individual',
      broker: 'Internal Broker',
      baseCurrency: 'IDR',
      isActive: true,
    },
    {
      id: 'acc-income-1',
      name: 'Income Account',
      type: 'individual',
      broker: 'Internal Broker',
      baseCurrency: 'IDR',
      isActive: true,
    },
  ],
  cashBalances: [
    {
      accountId: 'acc-growth-1',
      asOf: '2026-04-13T08:15:00.000Z',
      currency: 'IDR',
      availableAmount: 3500000,
      settledAmount: 3000000,
      pendingAmount: 500000,
      dataQuality: {
        verified: true,
        baseline_only: false,
        missing_avg_cost: false,
        provisional_pnl: false,
      },
    },
    {
      accountId: 'acc-income-1',
      asOf: '2026-04-13T08:15:00.000Z',
      currency: 'IDR',
      availableAmount: 1200000,
      settledAmount: 1200000,
      pendingAmount: 0,
      dataQuality: {
        verified: true,
        baseline_only: false,
        missing_avg_cost: false,
        provisional_pnl: true,
      },
    },
  ],
  holdings: [
    {
      accountId: 'acc-growth-1',
      asOf: '2026-04-13T08:15:00.000Z',
      symbol: 'BBCA.JK',
      assetClass: 'equity',
      quantity: 100,
      averageCost: 9200,
      marketPrice: 9800,
      marketValue: 980000,
      dataQuality: {
        verified: true,
        baseline_only: false,
        missing_avg_cost: false,
        provisional_pnl: false,
      },
    },
    {
      accountId: 'acc-growth-1',
      asOf: '2026-04-13T08:15:00.000Z',
      symbol: 'TLKM.JK',
      assetClass: 'equity',
      quantity: 400,
      averageCost: 3700,
      marketPrice: 3850,
      marketValue: 1540000,
      dataQuality: {
        verified: true,
        baseline_only: false,
        missing_avg_cost: false,
        provisional_pnl: false,
      },
    },
    {
      accountId: 'acc-income-1',
      asOf: '2026-04-13T08:15:00.000Z',
      symbol: 'SBR013',
      assetClass: 'bond',
      quantity: 1,
      marketValue: 2500000,
      dataQuality: {
        verified: false,
        baseline_only: true,
        missing_avg_cost: true,
        provisional_pnl: true,
      },
    },
  ],
  accountTotals: [
    {
      accountId: 'acc-growth-1',
      asOf: '2026-04-13T08:15:00.000Z',
      cashValue: 3500000,
      holdingsValue: 2520000,
      totalValue: 6020000,
      provisionalPnl: 120000,
      dataQuality: {
        verified: true,
        baseline_only: false,
        missing_avg_cost: false,
        provisional_pnl: false,
      },
    },
    {
      accountId: 'acc-income-1',
      asOf: '2026-04-13T08:15:00.000Z',
      cashValue: 1200000,
      holdingsValue: 2500000,
      totalValue: 3700000,
      provisionalPnl: 35000,
      dataQuality: {
        verified: false,
        baseline_only: true,
        missing_avg_cost: true,
        provisional_pnl: true,
      },
    },
  ],
};

export const sampleDashboardAccountCards: DashboardAccountCard[] = [
  {
    id: 'card-growth',
    accountId: 'acc-growth-1',
    title: 'Growth Account',
    subtitle: 'Long-term accumulation',
  },
  {
    id: 'card-income',
    accountId: 'acc-income-1',
    title: 'Income Account',
    subtitle: 'Coupon/dividend focus',
  },
];
