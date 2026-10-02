import { InteractionForm } from "@/components/crm/interaction-form";
import { PageHeader } from "@/components/shared/page-header";
import { getInteractionFormOptions } from "@/lib/crm/queries";

export default async function NewMeetingPage({ searchParams }: { searchParams: Promise<{ companyId?: string }> }) {
  const [{ companyId }, options] = await Promise.all([searchParams, getInteractionFormOptions()]);
  return (
    <div>
      <PageHeader title="Add Meeting" description="Log the conversation first, then add requirements, next action, and internal notes only if needed." />
      <InteractionForm {...options} defaultCompanyId={companyId} />
    </div>
  );
}
