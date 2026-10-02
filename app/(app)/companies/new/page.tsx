import { CompanyForm } from "@/components/crm/company-form";
import { PageHeader } from "@/components/shared/page-header";
import { getCompanyFormOptions } from "@/lib/crm/queries";

export default async function NewCompanyPage() {
  const options = await getCompanyFormOptions();

  return (
    <div>
      <PageHeader
        title="Add Company"
        description="Start with the company name. You can add contacts, meetings, and follow-ups later."
      />
      <CompanyForm {...options} />
    </div>
  );
}
