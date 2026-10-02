import { Badge } from "@/components/ui/badge";
import type { RecordStatus } from "@/lib/crm/types";

export function CompanyStatusBadge({ status }: { status: RecordStatus }) {
  const variant = status === "active" ? "success" : status === "inactive" ? "warning" : "secondary";
  return <Badge variant={variant}>{status}</Badge>;
}
