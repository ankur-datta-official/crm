import { notFound } from "next/navigation";
import { InteractionForm } from "@/components/crm/interaction-form";
import { PageHeader } from "@/components/shared/page-header";
import { getInteractionById, getInteractionFormOptions } from "@/lib/crm/queries";

export default async function EditMeetingPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [interaction, options] = await Promise.all([getInteractionById(id), getInteractionFormOptions()]);
  if (!interaction) notFound();
  return (
    <div>
      <PageHeader title="Edit Meeting" description="Update discussion notes, next action, and meeting context while keeping the original conversation history intact." />
      <InteractionForm interaction={interaction} {...options} />
    </div>
  );
}
