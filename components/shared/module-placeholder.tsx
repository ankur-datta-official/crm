import { LucideIcon } from "lucide-react";
import { EmptyState } from "@/components/shared/empty-state";
import { PageHeader } from "@/components/shared/page-header";

type ModulePlaceholderProps = {
  title: string;
  description: string;
  emptyTitle: string;
  emptyDescription: string;
  icon: LucideIcon;
};

export function ModulePlaceholder({
  title,
  description,
  emptyTitle,
  emptyDescription,
  icon,
}: ModulePlaceholderProps) {
  return (
    <div>
      <PageHeader title={title} description={description} />
      <EmptyState title={emptyTitle} description={emptyDescription} icon={icon} />
    </div>
  );
}
