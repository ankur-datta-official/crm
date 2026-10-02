import { Badge } from "@/components/ui/badge";
import type { HelpRequestStatus, HelpRequestPriority, HelpRequestType } from "@/lib/crm/types";
import { cn } from "@/lib/utils";

export function HelpRequestStatusBadge({ status, className }: { status: HelpRequestStatus; className?: string }) {
  const variant =
    status === "resolved" ? "success" :
    status === "in_progress" ? "info" :
    status === "rejected" ? "destructive" :
    status === "archived" ? "secondary" :
    "warning";

  return (
    <Badge variant={variant as any} className={cn("capitalize", className)}>
      {status.replace("_", " ")}
    </Badge>
  );
}

export function HelpRequestPriorityBadge({ priority, className }: { priority: HelpRequestPriority; className?: string }) {
  const variant =
    priority === "urgent" ? "destructive" :
    priority === "high" ? "warning" :
    priority === "medium" ? "secondary" :
    "outline";

  return (
    <Badge variant={variant as any} className={cn("capitalize", className)}>
      {priority}
    </Badge>
  );
}

export function HelpRequestTypeBadge({ type, className }: { type: HelpRequestType; className?: string }) {
  return (
    <Badge variant="outline" className={cn("whitespace-nowrap", className)}>
      {type}
    </Badge>
  );
}
