import { PageHeader } from "@/components/shared/page-header";
import { DocumentForm } from "@/components/crm/document-form";
import { getDocumentFormOptions } from "@/lib/crm/queries";

export const metadata = {
  title: "Upload Document | CRM",
};

type PageProps = {
  searchParams: Promise<{
    companyId?: string;
    contactId?: string;
    interactionId?: string;
    followupId?: string;
  }>;
};

export default async function NewDocumentPage({ searchParams }: PageProps) {
  const { 
    companyId, 
    contactId, 
    interactionId, 
    followupId 
  } = await searchParams;
  
  const options = await getDocumentFormOptions();

  return (
    <div className="space-y-6 max-w-5xl mx-auto">
      <PageHeader
        title="Upload Document"
        description="Upload the file first, then attach extra CRM context like meeting or follow-up records if it helps your team."
      />

      <DocumentForm 
        {...options} 
        initialCompanyId={companyId}
        initialContactId={contactId}
        initialInteractionId={interactionId}
        initialFollowupId={followupId}
      />
    </div>
  );
}
