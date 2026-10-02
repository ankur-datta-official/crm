import { ContactForm } from "@/components/crm/contact-form";
import { PageHeader } from "@/components/shared/page-header";
import { getContactFormOptions } from "@/lib/crm/queries";

export default async function NewContactPage({
  searchParams,
}: {
  searchParams: Promise<{ companyId?: string }>;
}) {
  const [{ companyId }, options] = await Promise.all([
    searchParams,
    getContactFormOptions(),
  ]);

  return (
    <div>
      <PageHeader
        title="Add Contact"
        description="Add a decision maker or stakeholder under the right company so meetings and follow-ups stay connected."
      />
      <ContactForm companies={options.companies} defaultCompanyId={companyId} />
    </div>
  );
}
