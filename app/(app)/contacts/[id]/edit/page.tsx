import { notFound } from "next/navigation";
import { ContactForm } from "@/components/crm/contact-form";
import { PageHeader } from "@/components/shared/page-header";
import { getContactById, getContactFormOptions } from "@/lib/crm/queries";

export default async function EditContactPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [contact, options] = await Promise.all([
    getContactById(id),
    getContactFormOptions(),
  ]);

  if (!contact) {
    notFound();
  }

  return (
    <div>
      <PageHeader
        title="Edit Contact"
        description="Update relationship details, communication preferences, and company alignment for this contact."
      />
      <ContactForm contact={contact} companies={options.companies} />
    </div>
  );
}
