import { StatusBadge } from "@/components/shared/status-badge";

export function UserStatusBadge({ active }: { active: boolean }) {
  return <StatusBadge status={active ? "Active" : "Inactive"} />;
}
