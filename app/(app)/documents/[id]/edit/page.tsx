import { notFound } from "next/navigation";
import { PageHeader } from "@/components/shared/page-header";
import { DocumentForm } from "@/components/crm/document-form";
import { getDocumentById } from "@/lib/crm/document-queries";
import { getDocumentFormOptions } from "@/lib/crm/queries";

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const document = await getDocumentById(id);
  return {
    title: `Edit ${document?.title ?? "Document"} | CRM`,
  };
}

export default async function EditDocumentPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [document, options] = await Promise.all([
    getDocumentById(id),
    getDocumentFormOptions(),
  ]);

  if (!document) {
    notFound();
  }

  return (
    <div className="space-y-6 max-w-5xl mx-auto">
      <PageHeader
        title="Edit Document"
        description={`Update the metadata and CRM links for ${document.title}.`}
      />

      <DocumentForm 
        document={document} 
        {...options} 
      />
    </div>
  );
}
