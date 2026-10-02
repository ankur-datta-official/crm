import { Badge } from "@/components/ui/badge";

export function PrimaryContactBadge({ primary }: { primary: boolean }) {
  return primary ? <Badge variant="success">Primary</Badge> : <Badge variant="secondary">Secondary</Badge>;
}
