import { notFound } from "next/navigation";
import { Suspense } from "react";
import { getHelpRequestById } from "@/lib/crm/help-request-queries";
import { getHelpRequestFormOptions } from "@/lib/crm/queries";
import { PageHeader } from "@/components/shared/page-header";
import { HelpRequestForm } from "@/components/crm/help-request-form";
import { LoadingSkeleton } from "@/components/shared/loading-skeleton";

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const helpRequest = await getHelpRequestById(id);
  return {
    title: helpRequest ? `Edit ${helpRequest.title} | SaaS CRM` : "Edit Help Request",
  };
}

export default async function EditHelpRequestPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const helpRequest = await getHelpRequestById(id);

  if (!helpRequest) {
    notFound();
  }

  return (
    <div className="container py-6">
      <PageHeader
        title="Edit Help Request"
        description="Update the request details, ownership, or resolution status without losing the original context."
      />
      <div className="mt-6 max-w-5xl">
        <Suspense fallback={<LoadingSkeleton />}>
          <EditHelpRequestLoader helpRequestId={id} />
        </Suspense>
      </div>
    </div>
  );
}

async function EditHelpRequestLoader({ helpRequestId }: { helpRequestId: string }) {
  const [helpRequest, { companies, contacts, interactions, followups, documents, teamMembers }] = await Promise.all([
    getHelpRequestById(helpRequestId),
    getHelpRequestFormOptions(),
  ]);

  if (!helpRequest) return null;

  return (
    <HelpRequestForm
      helpRequest={helpRequest}
      companies={companies}
      contacts={contacts}
      interactions={interactions}
      followups={followups}
      documents={documents}
      teamMembers={teamMembers}
    />
  );
}
