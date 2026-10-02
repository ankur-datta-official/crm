import { Badge } from "@/components/ui/badge";

export function DecisionRoleBadge({ role }: { role?: string | null }) {
  if (!role) return <Badge variant="secondary">No role</Badge>;
  const variant = ["Owner", "CEO / MD", "Director"].includes(role) ? "success" : "outline";
  return <Badge variant={variant}>{role}</Badge>;
}
