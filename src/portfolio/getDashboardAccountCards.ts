import { connectAccountCardsToPortfolio } from './connectAccountCards';
import { sampleDashboardAccountCards, samplePortfolioSnapshot } from './sampleData';
import { DashboardAccountCard, PortfolioSnapshot } from './types';

/**
 * Mapping layer used by dashboard data loaders.
 * Keeps existing UI card shape and injects portfolio values + quality status.
 */
export function mapPortfolioSnapshotToDashboardCards(
  cards: DashboardAccountCard[] = sampleDashboardAccountCards,
  snapshot: PortfolioSnapshot = samplePortfolioSnapshot,
): DashboardAccountCard[] {
  return connectAccountCardsToPortfolio(cards, snapshot);
}
