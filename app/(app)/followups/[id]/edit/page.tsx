import { notFound } from "next/navigation";
import { Suspense } from "react";
import { getFollowupById } from "@/lib/crm/followup-queries";
import { getFollowupFormOptions } from "@/lib/crm/queries";
import { PageHeader } from "@/components/shared/page-header";
import { FollowupForm } from "@/components/crm/followup-form";
import { LoadingSkeleton } from "@/components/shared/loading-skeleton";

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const followup = await getFollowupById(id);
  return {
    title: followup ? `Edit ${followup.title} | SaaS CRM` : "Edit Follow-up",
  };
}

export default async function EditFollowupPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const followup = await getFollowupById(id);

  if (!followup) {
    notFound();
  }

  return (
    <div className="container py-6">
      <PageHeader
        title="Edit Follow-up"
        description="Adjust the schedule, ownership, or status of this follow-up without recreating it."
      />
      <div className="mt-6 max-w-5xl">
        <Suspense fallback={<LoadingSkeleton />}>
          <EditFollowupLoader followupId={id} />
        </Suspense>
      </div>
    </div>
  );
}

async function EditFollowupLoader({ followupId }: { followupId: string }) {
  const [followup, { companies, contacts, interactions, teamMembers }] = await Promise.all([
    getFollowupById(followupId),
    getFollowupFormOptions(),
  ]);

  if (!followup) return null;

  return (
    <FollowupForm
      followup={followup}
      companies={companies}
      contacts={contacts}
      interactions={interactions}
      teamMembers={teamMembers}
    />
  );
}
