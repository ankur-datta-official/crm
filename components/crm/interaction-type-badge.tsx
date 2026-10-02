import { Badge } from "@/components/ui/badge";

export function InteractionTypeBadge({ type }: { type: string }) {
  const variant = type.includes("Meeting") ? "success" : type.includes("WhatsApp") || type.includes("Email") ? "warning" : "secondary";
  return <Badge variant={variant}>{type}</Badge>;
}
