import { notFound } from "next/navigation";
import { CompanyForm } from "@/components/crm/company-form";
import { PageHeader } from "@/components/shared/page-header";
import { getCompanyById, getCompanyFormOptions } from "@/lib/crm/queries";

export default async function EditCompanyPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [company, options] = await Promise.all([
    getCompanyById(id),
    getCompanyFormOptions(),
  ]);

  if (!company) {
    notFound();
  }

  return (
    <div>
      <PageHeader
        title="Edit Company"
        description="Update company details, ownership, and pipeline progress without losing the existing CRM history."
      />
      <CompanyForm company={company} {...options} />
    </div>
  );
}
