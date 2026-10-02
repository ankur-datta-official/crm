import { BarChart3, ListChecks, Mail, Shield, Users } from "lucide-react";
import { TeamDashboardView } from "@/components/dashboard/team-dashboard-view";
import { PageHeader } from "@/components/shared/page-header";
import { GuidanceStrip } from "@/components/shared/guidance-strip";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { InvitationTable } from "@/components/team/invitation-table";
import { InviteUserForm } from "@/components/team/invite-user-form";
import { TeamPageTabs } from "@/components/team/team-page-tabs";
import { RoleTable } from "@/components/team/role-table";
import { TeamMemberTable } from "@/components/team/team-member-table";
import { TeamTargetManager } from "@/components/team/team-target-manager";
import { TeamWorkspacePanel } from "@/components/team/team-workspace-panel";
import { getTeamDashboardData, normalizeTeamDashboardFilters, resolveTeamDashboardScope } from "@/lib/dashboard/team-dashboard";
import { hasPermission, requirePermission } from "@/lib/auth/session";
import { formatDateTimeBD } from "@/lib/format/datetime";
import { getManagedActivityReport, getPerformanceTargetsForOrganization } from "@/lib/team/performance-queries";
import { getMemberWorkProgressSnapshots, getRecentScopedTaskUpdates, getScopedTeamTasks, getTeamWorkloadSummary, resolveTeamTaskScope } from "@/lib/team/task-queries";
import {
  getCurrentUserId,
  getPermissions,
  getRolesWithPermissions,
  getTeamInvitations,
  getTeamMembers,
} from "@/lib/team/team-queries";

type TeamPageProps = {
  searchParams: Promise<{
    tab?: string;
    from?: string;
    to?: string;
    memberId?: string;
    managerId?: string;
    teamId?: string;
    page?: string;
  }>;
};

export default async function TeamPage({ searchParams }: TeamPageProps) {
  await requirePermission("team.view");
  const params = await searchParams;
  const currentPage = normalizePositivePage(params.page);
  const currentTab = params.tab === "invitations" || params.tab === "roles" || params.tab === "work" || params.tab === "performance" ? params.tab : "members";

  const [members, invitations, roles, permissions, currentUserId, canInvite, canUpdateRole, canDeactivate, canManageRoles, canManageHierarchy, canManageTargets, canViewActivity, performanceTargets, managedActivity, taskScope] =
    await Promise.all([
      getTeamMembers(),
      getTeamInvitations(),
      getRolesWithPermissions(),
      getPermissions(),
      getCurrentUserId(),
      hasPermission("team.invite"),
      hasPermission("team.update_role"),
      hasPermission("team.deactivate"),
      hasPermission("settings.manage"),
      hasPermission("settings.manage").then((allowed) => allowed || hasPermission("team.manage_hierarchy")),
      hasPermission("settings.manage").then((allowed) => allowed || hasPermission("team.manage_targets")),
      hasPermission("settings.manage").then((allowed) => allowed || hasPermission("team.view_activity")),
      getPerformanceTargetsForOrganization(),
      getManagedActivityReport(),
      resolveTeamTaskScope(),
    ]);

  const currentUserMember = members.find((member) => member.id === currentUserId) ?? null;
  const canViewTeamPerformance = Boolean(
    currentUserMember?.is_workspace_owner
    || currentUserMember?.role_slug === "organization-admin"
    || currentUserMember?.role_slug === "sales-manager",
  );

  const [teamTasks, recentTaskUpdates, memberSnapshots, workSummary] = currentTab === "work"
    ? await Promise.all([
        getScopedTeamTasks(taskScope, { includeCompleted: true }),
        getRecentScopedTaskUpdates(taskScope, 20),
        getMemberWorkProgressSnapshots(taskScope),
        getTeamWorkloadSummary(taskScope),
      ])
    : [[], [], [], {
      teamTaskCount: 0,
      overdueTaskCount: 0,
      blockedTaskCount: 0,
      doneTaskCount: 0,
      noActivityMemberCount: 0,
      completionRate: 0,
    }];

  const performanceFilters = normalizeTeamDashboardFilters(params);
  const performanceDashboardData = currentTab === "performance" && canViewTeamPerformance
    ? await (async () => {
        const scope = await resolveTeamDashboardScope(performanceFilters);
        const normalizedScope = currentUserMember?.role_slug === "sales-manager" && scope.viewerMode !== "team"
          ? {
              ...scope,
              visibleUserIds: [],
              selectedUserIds: [],
              selectedManagerId: null,
              selectedTeamId: null,
              selectedMemberId: null,
              selectedMember: null,
              availableMembers: [],
              availableManagers: [],
              availableTeams: [],
            }
          : scope;

        return getTeamDashboardData(normalizedScope, performanceFilters);
      })()
    : null;

  const taskScopedMembers = members.filter((member) => taskScope.visibleUserIds.includes(member.id));

  const pendingInvitationCount = invitations.filter((invitation) => invitation.status === "pending").length;

  return (
    <div className="space-y-6">
      <PageHeader
        title="Team"
        description="Manage organization members, invitation links, roles, and CRM access permissions."
        actions={canInvite ? <InviteUserForm roles={roles} /> : undefined}
      />
      <GuidanceStrip dismissible storageKey="crm-tip-team">
        Team invitations now send an authentication email automatically. You can still copy the invite link manually as a backup.
      </GuidanceStrip>

      <TeamPageTabs currentTab={currentTab} className="space-y-4">
        <TabsList className="grid w-full grid-cols-5 md:w-auto">
          <TabsTrigger value="members">
            <Users className="mr-2 h-4 w-4" />
            Team Members
          </TabsTrigger>
          <TabsTrigger value="work">
            <ListChecks className="mr-2 h-4 w-4" />
            Work
          </TabsTrigger>
          <TabsTrigger value="performance">
            <BarChart3 className="mr-2 h-4 w-4" />
            Performance
          </TabsTrigger>
          <TabsTrigger value="invitations">
            <Mail className="mr-2 h-4 w-4" />
            Invitations
            {pendingInvitationCount > 0 ? <Badge className="ml-2">{pendingInvitationCount}</Badge> : null}
          </TabsTrigger>
          <TabsTrigger value="roles">
            <Shield className="mr-2 h-4 w-4" />
            Roles & Permissions
          </TabsTrigger>
        </TabsList>

        <TabsContent value="members" className="space-y-4">
          <TeamTargetManager members={members} targets={performanceTargets} canManage={canManageTargets} />

          {canViewActivity && managedActivity.length > 0 ? (
            <Card>
              <CardHeader>
                <CardTitle>Junior activity report</CardTitle>
                <CardDescription>Recent company, meeting, and follow-up updates from your directly managed team members.</CardDescription>
              </CardHeader>
              <CardContent className="space-y-3">
                {managedActivity.map((item) => (
                  <div key={item.id} className="rounded-xl border bg-white px-4 py-3 dark:border-slate-800 dark:bg-slate-900/85">
                    <div className="flex flex-col gap-1 md:flex-row md:items-center md:justify-between">
                      <div className="font-medium text-foreground">{item.actor_name}</div>
                      <div className="text-xs text-muted-foreground">{formatDateTimeBD(item.created_at)}</div>
                    </div>
                    <div className="mt-2 text-sm text-muted-foreground">
                      {formatManagedActivity(item.action, item.entity_type)}
                    </div>
                  </div>
                ))}
              </CardContent>
            </Card>
          ) : null}

          <TeamMemberTable
            members={members}
            roles={roles}
            currentUserId={currentUserId}
            canUpdateRole={canUpdateRole}
            canDeactivate={canDeactivate}
            canManageHierarchy={canManageHierarchy}
          />
        </TabsContent>

        <TabsContent value="work" className="space-y-4">
          <TeamWorkspacePanel
            key={teamTasks.map((task) => `${task.id}:${task.updated_at}`).join("|")}
            mode="team"
            tasks={teamTasks}
            recentUpdates={recentTaskUpdates}
            memberSnapshots={memberSnapshots}
            summary={workSummary}
            members={taskScopedMembers}
            currentUserId={currentUserId ?? ""}
            canAssignTasks={taskScope.canAssignTasks}
          />
        </TabsContent>

        <TabsContent value="performance" className="space-y-4">
          {canViewTeamPerformance && performanceDashboardData ? (
            <TeamDashboardView data={performanceDashboardData} navigationMode="team-tab" currentPage={currentPage} />
          ) : (
            <Card>
              <CardHeader>
                <CardTitle>Team performance access required</CardTitle>
                <CardDescription>
                  This performance dashboard stays limited to organization admins and sales managers so team-wide insights remain scoped safely.
                </CardDescription>
              </CardHeader>
              <CardContent className="text-sm text-muted-foreground">
                You can still use Team Members and Work Management from this page.
              </CardContent>
            </Card>
          )}
        </TabsContent>

        <TabsContent value="invitations" className="space-y-4">
          {!canInvite ? (
            <div className="rounded-lg border bg-white p-4 text-sm text-muted-foreground dark:border-slate-800 dark:bg-slate-900/85">
              You can review invitation history here, but you do not have permission to create or manage invites.
            </div>
          ) : null}
          <InvitationTable invitations={invitations} canManage={canInvite} />
        </TabsContent>

        <TabsContent value="roles" className="space-y-4">
          {!canManageRoles ? (
            <div className="rounded-lg border bg-white p-4 text-sm text-muted-foreground dark:border-slate-800 dark:bg-slate-900/85">
              You can review roles and permissions here. Editing is limited to users with settings management access.
            </div>
          ) : null}
          <RoleTable roles={roles} permissions={permissions} canManage={canManageRoles} />
        </TabsContent>
      </TeamPageTabs>
    </div>
  );
}

function formatManagedActivity(action: string, entityType: string | null) {
  const normalizedAction = action.replaceAll(".", " ");
  const normalizedEntity = entityType ? entityType.replaceAll("_", " ") : "record";
  return `${normalizedAction} on ${normalizedEntity}`;
}

function normalizePositivePage(value?: string) {
  const parsed = Number.parseInt(value ?? "1", 10);
  if (!Number.isFinite(parsed) || parsed < 1) {
    return 1;
  }

  return parsed;
}
