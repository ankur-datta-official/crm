import { PipelineBoard } from "@/components/pipeline/pipeline-board";
import { requirePermission } from "@/lib/auth/session";
import { getPipelineBoard } from "@/lib/crm/queries";

export const metadata = {
  title: "Pipeline | SaaS CRM",
  description: "Track deal movement across the CRM pipeline board.",
};

export default async function PipelinePage() {
  await requirePermission("companies.view");
  const board = await getPipelineBoard();

  return <PipelineBoard {...board} />;
}
