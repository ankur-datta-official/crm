import { Badge } from "@/components/ui/badge";
import type { LeadTemperature } from "@/lib/crm/types";

export function LeadTemperatureBadge({ temperature }: { temperature: LeadTemperature }) {
  const variant = temperature === "very_hot" || temperature === "hot" ? "destructive" : temperature === "warm" ? "warning" : "secondary";
  return <Badge variant={variant}>{temperature === "very_hot" ? "Very Hot" : temperature}</Badge>;
}
