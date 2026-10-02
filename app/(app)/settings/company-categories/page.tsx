import { CompanyCategorySettingsManager } from "@/components/crm/settings-manager";
import { PageHeader } from "@/components/shared/page-header";
import { getCompanyCategories } from "@/lib/crm/queries";
import { requirePermission } from "@/lib/auth/session";

export default async function CompanyCategoriesSettingsPage() {
  await requirePermission("settings.manage");
  const categories = await getCompanyCategories(true);

  return (
    <div>
      <PageHeader
        title="Company Categories"
        description="Manage company value tiers such as A+ High Value and B Medium Potential."
      />
      <CompanyCategorySettingsManager categories={categories} />
    </div>
  );
}
