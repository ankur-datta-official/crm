import { PageHeader } from "@/components/shared/page-header";
import { ScoringAdminPanel } from "@/components/scoring/scoring-ui";
import { requirePermission } from "@/lib/auth/session";
import { getOrganizationRewardRedemptions, getScoringAdminDashboard } from "@/lib/scoring/queries";

export default async function ScoringSettingsPage() {
  await requirePermission("scoring.manage");
  const [dashboard, redemptions] = await Promise.all([
    getScoringAdminDashboard(),
    getOrganizationRewardRedemptions(50),
  ]);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Scoring Settings"
        description="Manage point allocations, reward thresholds, challenge bonuses, and manual wallet adjustments."
      />
      <ScoringAdminPanel
        rules={dashboard.rules}
        sourceRules={dashboard.sourceRules}
        rewards={dashboard.rewards}
        challenges={dashboard.challenges}
        redemptions={redemptions}
        walletLeaders={dashboard.leaderboard}
      />
    </div>
  );
}
