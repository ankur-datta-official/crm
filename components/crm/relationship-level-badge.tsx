import { Badge } from "@/components/ui/badge";

export function RelationshipLevelBadge({ level }: { level?: string | null }) {
  if (!level) return <Badge variant="secondary">Unknown</Badge>;
  const variant = level === "Strong" || level === "Decision Maker" ? "success" : level === "Risky" ? "destructive" : "warning";
  return <Badge variant={variant}>{level}</Badge>;
}
