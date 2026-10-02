import { Badge, type BadgeProps } from "@/components/ui/badge";

type StatusTone = NonNullable<BadgeProps["variant"]>;

const statusTone: Record<string, StatusTone> = {
  active: "success",
  hot: "destructive",
  pending: "warning",
  completed: "success",
  missed: "destructive",
  draft: "secondary",
};

export function StatusBadge({ status }: { status: string }) {
  const key = status.toLowerCase();
  return <Badge variant={statusTone[key] ?? "outline"}>{status}</Badge>;
}
