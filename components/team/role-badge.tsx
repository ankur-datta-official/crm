import { StatusBadge } from "@/components/shared/status-badge";
import { cn } from "@/lib/utils";

const roleColors: Record<string, string> = {
  "organization-admin": "bg-red-100 text-red-800",
  "sales-manager": "bg-blue-100 text-blue-800",
  "sales-executive": "bg-green-100 text-green-800",
  "support-user": "bg-purple-100 text-purple-800",
  viewer: "bg-gray-100 text-gray-800",
};

export function RoleBadge({ name }: { name: string }) {
  const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, "-");
  const colorClass = roleColors[slug] || "bg-muted text-muted-foreground";

  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
        colorClass
      )}
    >
      {name}
    </span>
  );
}

export function UserStatusBadge({ active }: { active: boolean }) {
  return <StatusBadge status={active ? "Active" : "Inactive"} />;
}

export function InvitationStatusBadge({ status }: { status: string }) {
  const statusConfig: Record<string, { label: string; className: string }> = {
    pending: { label: "Pending", className: "bg-yellow-100 text-yellow-800" },
    accepted: { label: "Accepted", className: "bg-green-100 text-green-800" },
    cancelled: { label: "Cancelled", className: "bg-gray-100 text-gray-800" },
    expired: { label: "Expired", className: "bg-red-100 text-red-800" },
  };

  const config = statusConfig[status] || { label: status, className: "bg-muted text-muted-foreground" };

  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium",
        config.className
      )}
    >
      {config.label}
    </span>
  );
}
