import { PageHeader } from "@/components/shared/page-header";
import { GuidanceStrip } from "@/components/shared/guidance-strip";
import { TeamWorkspacePanel } from "@/components/team/team-workspace-panel";
import { requirePermission } from "@/lib/auth/session";
import { getCurrentUserId, getTeamMembers } from "@/lib/team/team-queries";
import { getMemberWorkProgressSnapshots, getMyWorkSummary, getTeamWorkloadSummary } from "@/lib/team/task-queries";

export default async function MyWorkPage() {
  await requirePermission("team.tasks.view");

  const [myWork, members, currentUserId] = await Promise.all([
    getMyWorkSummary(),
    getTeamMembers(),
    getCurrentUserId(),
  ]);
  const [memberSnapshots, summary] = await Promise.all([
    getMemberWorkProgressSnapshots(myWork.scope),
    getTeamWorkloadSummary(myWork.scope),
  ]);
  const scopedMembers = members.filter((member) => myWork.scope.visibleUserIds.includes(member.id));

  return (
    <div className="space-y-6">
      <PageHeader
        title="My Work"
        description="Stay on top of your internal tasks, personal progress updates, and manager-visible execution history."
      />
      <GuidanceStrip dismissible storageKey="crm-tip-my-work">
        Keep your progress current here so managers can see task movement without interrupting your core CRM workflow.
      </GuidanceStrip>

      <TeamWorkspacePanel
        key={myWork.tasks.map((task) => `${task.id}:${task.updated_at}`).join("|")}
        mode="self"
        tasks={myWork.tasks}
        recentUpdates={myWork.recentUpdates}
        memberSnapshots={memberSnapshots}
        summary={summary}
        members={scopedMembers}
        currentUserId={currentUserId ?? myWork.scope.currentUserId}
        canAssignTasks={myWork.scope.canAssignTasks}
      />
    </div>
  );
}
