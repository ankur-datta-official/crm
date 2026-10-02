import { Suspense } from "react";
import { getHelpRequestFormOptions } from "@/lib/crm/queries";
import { PageHeader } from "@/components/shared/page-header";
import { HelpRequestForm } from "@/components/crm/help-request-form";
import { LoadingSkeleton } from "@/components/shared/loading-skeleton";

export const metadata = {
  title: "New Help Request | SaaS CRM",
  description: "Create a new help request for support.",
};

export default async function NewHelpRequestPage({
  searchParams,
}: {
  searchParams: Promise<{ company?: string; contact?: string; interaction?: string; followup?: string; document?: string }>;
}) {
  const params = await searchParams;

  return (
    <div className="container py-6">
      <PageHeader
        title="New Help Request"
        description="Explain what help is needed first, then link related CRM records or assign ownership if useful."
      />
      <div className="mt-6 max-w-5xl">
        <Suspense fallback={<LoadingSkeleton />}>
          <HelpRequestFormLoader
            defaultCompanyId={params.company}
            defaultContactId={params.contact}
            defaultInteractionId={params.interaction}
            defaultFollowupId={params.followup}
            defaultDocumentId={params.document}
          />
        </Suspense>
      </div>
    </div>
  );
}

async function HelpRequestFormLoader({
  defaultCompanyId,
  defaultContactId,
  defaultInteractionId,
  defaultFollowupId,
  defaultDocumentId,
}: {
  defaultCompanyId?: string;
  defaultContactId?: string;
  defaultInteractionId?: string;
  defaultFollowupId?: string;
  defaultDocumentId?: string;
}) {
  const { companies, contacts, interactions, followups, documents, teamMembers } = await getHelpRequestFormOptions();

  return (
    <HelpRequestForm
      companies={companies}
      contacts={contacts}
      interactions={interactions}
      followups={followups}
      documents={documents}
      teamMembers={teamMembers}
      defaultCompanyId={defaultCompanyId}
      defaultContactId={defaultContactId}
      defaultInteractionId={defaultInteractionId}
      defaultFollowupId={defaultFollowupId}
      defaultDocumentId={defaultDocumentId}
    />
  );
}
