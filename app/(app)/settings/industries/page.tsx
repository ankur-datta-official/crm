import { IndustrySettingsManager } from "@/components/crm/settings-manager";
import { PageHeader } from "@/components/shared/page-header";
import { getIndustries } from "@/lib/crm/queries";
import { requirePermission } from "@/lib/auth/session";

export default async function IndustriesSettingsPage() {
  await requirePermission("settings.manage");
  const industries = await getIndustries(true);

  return (
    <div>
      <PageHeader
        title="Industries"
        description="Add, edit, and archive industry options used when creating company leads."
      />
      <IndustrySettingsManager industries={industries} />
    </div>
  );
}
