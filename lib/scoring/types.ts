export type ScoreActionKey =
  | "lead_created"
  | "lead_qualified"
  | "lead_converted_won"
  | "followup_completed"
  | "lead_source_bonus"
  | "weekly_conversion_bonus"
  | "lead_referral"
  | "team_invite_accepted"
  | "challenge_bonus"
  | "reward_redeemed"
  | "manual_adjustment";

export type WalletTransactionType = "earn" | "bonus" | "redeem" | "adjustment" | "refund";

export type WalletTransaction = {
  id: string;
  organization_id: string;
  user_id: string;
  transaction_type: WalletTransactionType;
  action_key: ScoreActionKey | string;
  points_delta: number;
  balance_after: number;
  company_id: string | null;
  followup_id: string | null;
  challenge_id: string | null;
  reward_id: string | null;
  source_record_id: string | null;
  source_record_type: string | null;
  idempotency_key: string;
  metadata: Record<string, unknown>;
  created_by: string | null;
  created_at: string;
};

export type WalletSummary = {
  user_id: string;
  organization_id: string;
  full_name: string | null;
  email: string;
  wallet_balance: number;
  wallet_lifetime_earned: number;
  recent_transactions: Array<{
    id: string;
    transaction_type: WalletTransactionType;
    action_key: ScoreActionKey | string;
    points_delta: number;
    balance_after: number;
    company_id: string | null;
    followup_id: string | null;
    reward_id: string | null;
    metadata: Record<string, unknown>;
    created_at: string;
  }>;
  badges: UserBadge[];
  streaks: UserStreak[];
  challenge_progress: UserChallengeProgress[];
};

export type LeaderboardEntry = {
  rank: number;
  user_id: string;
  full_name: string | null;
  email: string;
  avatar_url: string | null;
  wallet_balance: number;
  wallet_lifetime_earned: number;
  period_points: number;
};

export type LeadScoreRule = {
  id: string;
  organization_id: string;
  action_key: ScoreActionKey | string;
  name: string;
  description: string | null;
  points: number;
  is_active: boolean;
  rule_scope: Record<string, unknown>;
  created_at: string;
  updated_at: string;
};

export type LeadSourceScoreRule = {
  id: string;
  organization_id: string;
  source_name: string;
  normalized_source: string;
  bonus_points: number;
  is_active: boolean;
  rule_scope: Record<string, unknown>;
  created_at: string;
  updated_at: string;
};

export type ChallengeTemplate = {
  id: string;
  organization_id: string;
  name: string;
  description: string | null;
  cadence: "daily" | "weekly";
  target_metric: ScoreActionKey | string;
  target_count: number;
  bonus_points: number;
  is_active: boolean;
  starts_at: string | null;
  ends_at: string | null;
  config: Record<string, unknown>;
  created_at: string;
  updated_at: string;
};

export type UserChallengeProgress = {
  id: string;
  challenge_template_id: string;
  name?: string;
  description?: string | null;
  cadence?: "daily" | "weekly";
  target_metric?: ScoreActionKey | string;
  progress_count: number;
  target_count: number;
  is_completed: boolean;
  completed_at: string | null;
  window_starts_at: string;
  window_ends_at: string;
  updated_at?: string;
};

export type Reward = {
  id: string;
  organization_id: string;
  name: string;
  description: string | null;
  reward_type: "badge" | "discount" | "premium_feature" | "manual_reward";
  cost_points: number;
  feature_key: string | null;
  inventory: number | null;
  fulfillment_mode: "automatic" | "manual";
  is_active: boolean;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
};

export type RewardRedemption = {
  id: string;
  organization_id: string;
  user_id: string;
  reward_id: string;
  points_spent: number;
  status: "pending" | "fulfilled" | "rejected" | "cancelled";
  fulfillment_notes: string | null;
  processed_by: string | null;
  processed_at: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
  rewards_catalog?: Pick<Reward, "id" | "name" | "reward_type" | "cost_points"> | null;
};

export type UserBadge = {
  id: string;
  organization_id?: string;
  user_id?: string;
  reward_id: string | null;
  badge_key: string;
  badge_name: string;
  badge_description: string | null;
  metadata: Record<string, unknown>;
  awarded_at: string;
  awarded_by?: string | null;
};

export type UserStreak = {
  id: string;
  streak_key: string;
  current_streak: number;
  best_streak: number;
  last_activity_date: string | null;
  updated_at: string;
};

export type ScoringActivityLog = {
  id: string;
  organization_id: string;
  wallet_transaction_id: string | null;
  user_id: string;
  actor_user_id: string | null;
  action_key: ScoreActionKey | string;
  title: string;
  description: string | null;
  points_delta: number;
  company_id: string | null;
  followup_id: string | null;
  challenge_id: string | null;
  reward_id: string | null;
  source_record_id: string | null;
  source_record_type: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
};

export type ScoringEventResult = {
  transaction_id: string | null;
  points_awarded: number;
  balance_after: number;
  applied: boolean;
};

