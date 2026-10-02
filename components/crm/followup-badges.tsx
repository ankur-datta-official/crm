import { Badge } from "@/components/ui/badge";
import type { FollowupStatus, FollowupPriority, FollowupType } from "@/lib/crm/types";
import { cn } from "@/lib/utils";

export function FollowupStatusBadge({ status, className }: { status: FollowupStatus; className?: string }) {
  const variant = 
    status === "completed" ? "success" : 
    status === "pending" ? "warning" : 
    status === "rescheduled" ? "secondary" : 
    status === "cancelled" ? "destructive" : 
    "outline";

  return (
    <Badge variant={variant as any} className={cn("capitalize", className)}>
      {status}
    </Badge>
  );
}

export function FollowupPriorityBadge({ priority, className }: { priority: FollowupPriority; className?: string }) {
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

export function FollowupTypeBadge({ type, className }: { type: FollowupType; className?: string }) {
  return (
    <Badge variant="outline" className={cn("whitespace-nowrap", className)}>
      {type}
    </Badge>
  );
}
