import { PageHeader } from "@/components/shared/page-header";
import { ChallengeProgressPanel, ScoringActivityPanel, WalletSummaryPanel } from "@/components/scoring/scoring-ui";
import { ProfileSettingsForm } from "@/components/settings/profile-settings-form";
import { getCurrentProfileSettings } from "@/lib/profile/profile-actions";
import { requireOrganization } from "@/lib/auth/session";
import { getCurrentUserWalletSummary, getUserWalletTransactions } from "@/lib/scoring/queries";

export default async function ProfileSettingsPage() {
  await requireOrganization();
  const [profile, walletSummary, transactions] = await Promise.all([
    getCurrentProfileSettings(),
    getCurrentUserWalletSummary(),
    getUserWalletTransactions(undefined, 25),
  ]);

  const activity = transactions.map((item) => ({
    id: item.id,
    organization_id: item.organization_id,
    wallet_transaction_id: item.id,
    user_id: item.user_id,
    actor_user_id: item.created_by,
    action_key: item.action_key,
    title: item.action_key.replaceAll("_", " "),
    description: (item.metadata?.reason as string | undefined) ?? null,
    points_delta: item.points_delta,
    company_id: item.company_id,
    followup_id: item.followup_id,
    challenge_id: item.challenge_id,
    reward_id: item.reward_id,
    source_record_id: item.source_record_id,
    source_record_type: item.source_record_type,
    metadata: item.metadata,
    created_at: item.created_at,
  }));

  return (
    <div className="space-y-6">
      <PageHeader
        title="Profile Settings"
        description="Update your personal CRM profile and account details."
      />
      <div className="grid gap-6 xl:grid-cols-[0.95fr_1.05fr]">
        <WalletSummaryPanel summary={walletSummary} />
        <ChallengeProgressPanel challenges={walletSummary?.challenge_progress ?? []} />
      </div>
      <ProfileSettingsForm profile={profile} />
      <ScoringActivityPanel
        activities={activity}
        title="Wallet Activity History"
        description="A running history of points earned, bonuses, and reward redemptions for your account."
      />
    </div>
  );
}
