import "server-only";

import { Prisma } from "@prisma/client";
import { getCurrentProfile, hasPermission, requireAuth, requireOrganization } from "@/lib/auth/session";
import { prisma } from "@/lib/prisma";
import { getManageableTeamMemberIds } from "@/lib/team/hierarchy";
import { getTeamMembers } from "@/lib/team/team-queries";
import { hasTeamTasksTables, isTeamTasksRelationMissingError } from "@/lib/team/task-support";
import type {
  MemberWorkProgressSnapshot,
  TeamTask,
  TeamTaskPriority,
  TeamTaskRelatedEntityType,
  TeamTaskStatus,
  TeamTaskUpdate,
  TeamWorkloadSummary,
} from "@/lib/team/types";

type TeamTaskRow = {
  id: string;
  organization_id: string;
  title: string;
  description: string | null;
  status: TeamTaskStatus;
  priority: TeamTaskPriority;
  progress_percent: number;
  start_date: Date | null;
  due_date: Date | null;
  completed_at: Date | null;
  created_by: string;
  assigned_to: string | null;
  manager_owner_id: string | null;
  related_entity_type: TeamTaskRelatedEntityType | null;
  related_entity_id: string | null;
  created_at: Date;
  updated_at: Date;
  creator_full_name: string | null;
  creator_email: string | null;
  assignee_full_name: string | null;
  assignee_email: string | null;
  manager_owner_full_name: string | null;
  manager_owner_email: string | null;
};

type TeamTaskUpdateRow = {
  id: string;
  team_task_id: string;
  organization_id: string;
  author_user_id: string | null;
  update_type: TeamTaskUpdate["update_type"];
  message: string | null;
  previous_status: TeamTaskStatus | null;
  next_status: TeamTaskStatus | null;
  previous_progress: number | null;
  next_progress: number | null;
  created_at: Date;
  author_full_name: string | null;
  author_email: string | null;
};

type ScopedTaskFilters = {
  assigneeId?: string | null;
  managerId?: string | null;
  status?: TeamTaskStatus | "all" | null;
  priority?: TeamTaskPriority | "all" | null;
  includeCompleted?: boolean;
  search?: string | null;
};

export type TeamTaskScope = {
  currentUserId: string;
  visibleUserIds: string[];
  manageableUserIds: string[];
  canAssignTasks: boolean;
  canManageAllTasks: boolean;
};

function buildUuidJoin(ids: string[]) {
  return Prisma.join(ids.map((id) => Prisma.sql`${id}::uuid`));
}

function formatDateOnly(value: Date | null) {
  return value ? value.toISOString().slice(0, 10) : null;
}

function mapTaskRow(row: TeamTaskRow): TeamTask {
  return {
    id: row.id,
    organization_id: row.organization_id,
    title: row.title,
    description: row.description,
    status: row.status,
    priority: row.priority,
    progress_percent: Number(row.progress_percent ?? 0),
    start_date: formatDateOnly(row.start_date),
    due_date: formatDateOnly(row.due_date),
    completed_at: row.completed_at?.toISOString() ?? null,
    created_by: row.created_by,
    assigned_to: row.assigned_to,
    manager_owner_id: row.manager_owner_id,
    related_entity_type: row.related_entity_type,
    related_entity_id: row.related_entity_id,
    created_at: row.created_at.toISOString(),
    updated_at: row.updated_at.toISOString(),
    creator: row.creator_email ? {
      id: row.created_by,
      full_name: row.creator_full_name,
      email: row.creator_email,
    } : null,
    assignee: row.assigned_to && row.assignee_email ? {
      id: row.assigned_to,
      full_name: row.assignee_full_name,
      email: row.assignee_email,
    } : null,
    manager_owner: row.manager_owner_id && row.manager_owner_email ? {
      id: row.manager_owner_id,
      full_name: row.manager_owner_full_name,
      email: row.manager_owner_email,
    } : null,
  };
}

function mapTaskUpdateRow(row: TeamTaskUpdateRow): TeamTaskUpdate {
  return {
    id: row.id,
    team_task_id: row.team_task_id,
    organization_id: row.organization_id,
    author_user_id: row.author_user_id,
    update_type: row.update_type,
    message: row.message,
    previous_status: row.previous_status,
    next_status: row.next_status,
    previous_progress: row.previous_progress,
    next_progress: row.next_progress,
    created_at: row.created_at.toISOString(),
    author: row.author_user_id && row.author_email ? {
      id: row.author_user_id,
      full_name: row.author_full_name,
      email: row.author_email,
    } : null,
  };
}

export async function resolveTeamTaskScope(): Promise<TeamTaskScope> {
  const user = await requireAuth();
  const [canManageAllPermission, canAssignPermission, canSettingsManage] = await Promise.all([
    hasPermission("team.tasks.manage_all"),
    hasPermission("team.tasks.assign"),
    hasPermission("settings.manage"),
  ]);
  const canManageAllTasks = Boolean(canManageAllPermission || canSettingsManage);
  const canAssignTasks = Boolean(canAssignPermission || canManageAllTasks);

  const manageableUserIds = canManageAllTasks
    ? (await getTeamMembers()).filter((member) => member.is_active).map((member) => member.id)
    : canAssignTasks
      ? await getManageableTeamMemberIds({ includeSelf: true, includeDescendants: true })
      : [user.id];

  const visibleUserIds = canManageAllTasks || canAssignTasks ? manageableUserIds : [user.id];

  return {
    currentUserId: user.id,
    visibleUserIds: Array.from(new Set(visibleUserIds)),
    manageableUserIds: Array.from(new Set(manageableUserIds)),
    canAssignTasks: canManageAllTasks || canAssignTasks,
    canManageAllTasks,
  };
}

function buildTaskVisibilityClause(scope: TeamTaskScope) {
  if (scope.canManageAllTasks) {
    return Prisma.sql`true`;
  }

  const visibleUserIdsSql = buildUuidJoin(scope.visibleUserIds);
  return Prisma.sql`
    (
      tt.assigned_to in (${visibleUserIdsSql})
      or tt.created_by in (${visibleUserIdsSql})
      or tt.manager_owner_id in (${visibleUserIdsSql})
    )
  `;
}

function buildTaskFilterClause(filters: ScopedTaskFilters) {
  const clauses: Prisma.Sql[] = [];

  if (filters.assigneeId) {
    clauses.push(Prisma.sql`tt.assigned_to = ${filters.assigneeId}::uuid`);
  }

  if (filters.managerId) {
    clauses.push(Prisma.sql`tt.manager_owner_id = ${filters.managerId}::uuid`);
  }

  if (filters.status && filters.status !== "all") {
    clauses.push(Prisma.sql`tt.status = ${filters.status}`);
  } else if (!filters.includeCompleted) {
    clauses.push(Prisma.sql`tt.status <> 'done' and tt.status <> 'cancelled'`);
  }

  if (filters.priority && filters.priority !== "all") {
    clauses.push(Prisma.sql`tt.priority = ${filters.priority}`);
  }

  if (filters.search?.trim()) {
    const query = `%${filters.search.trim()}%`;
    clauses.push(Prisma.sql`(tt.title ilike ${query} or coalesce(tt.description, '') ilike ${query})`);
  }

  if (clauses.length === 0) {
    return Prisma.sql`true`;
  }

  return Prisma.sql`${Prisma.join(clauses, " and ")}`;
}

export async function getScopedTeamTasks(scope: TeamTaskScope, filters: ScopedTaskFilters = {}): Promise<TeamTask[]> {
  if (!(await hasTeamTasksTables())) {
    return [];
  }

  const organization = await requireOrganization();
  try {
    const rows = await prisma.$queryRaw<TeamTaskRow[]>(Prisma.sql`
      select
        tt.id::text as id,
        tt.organization_id::text as organization_id,
        tt.title,
        tt.description,
        tt.status,
        tt.priority,
        tt.progress_percent,
        tt.start_date,
        tt.due_date,
        tt.completed_at,
        tt.created_by::text as created_by,
        tt.assigned_to::text as assigned_to,
        tt.manager_owner_id::text as manager_owner_id,
        tt.related_entity_type,
        tt.related_entity_id::text as related_entity_id,
        tt.created_at,
        tt.updated_at,
        creator.full_name as creator_full_name,
        creator.email as creator_email,
        assignee.full_name as assignee_full_name,
        assignee.email as assignee_email,
        manager.full_name as manager_owner_full_name,
        manager.email as manager_owner_email
      from public.team_tasks tt
      join public.profiles creator
        on creator.id = tt.created_by
      left join public.profiles assignee
        on assignee.id = tt.assigned_to
      left join public.profiles manager
        on manager.id = tt.manager_owner_id
      where tt.organization_id = ${organization.id}::uuid
        and ${buildTaskVisibilityClause(scope)}
        and ${buildTaskFilterClause(filters)}
      order by
        case tt.priority
          when 'urgent' then 1
          when 'high' then 2
          when 'medium' then 3
          else 4
        end asc,
        tt.due_date asc nulls last,
        tt.updated_at desc
    `);

    return rows.map(mapTaskRow);
  } catch (error) {
    if (isTeamTasksRelationMissingError(error)) {
      return [];
    }
    throw error;
  }
}

export async function getTeamTaskTimeline(taskId: string, scope: TeamTaskScope, limit = 20): Promise<TeamTaskUpdate[]> {
  if (!(await hasTeamTasksTables())) {
    return [];
  }

  const organization = await requireOrganization();
  const taskRows = await prisma.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    select tt.id::text as id
    from public.team_tasks tt
    where tt.organization_id = ${organization.id}::uuid
      and tt.id = ${taskId}::uuid
      and ${buildTaskVisibilityClause(scope)}
    limit 1
  `);

  if (!taskRows[0]) {
    return [];
  }

  const rows = await prisma.$queryRaw<TeamTaskUpdateRow[]>(Prisma.sql`
    select
      ttu.id::text as id,
      ttu.team_task_id::text as team_task_id,
      ttu.organization_id::text as organization_id,
      ttu.author_user_id::text as author_user_id,
      ttu.update_type,
      ttu.message,
      ttu.previous_status,
      ttu.next_status,
      ttu.previous_progress,
      ttu.next_progress,
      ttu.created_at,
      author.full_name as author_full_name,
      author.email as author_email
    from public.team_task_updates ttu
    left join public.profiles author
      on author.id = ttu.author_user_id
    where ttu.organization_id = ${organization.id}::uuid
      and ttu.team_task_id = ${taskId}::uuid
    order by ttu.created_at desc
    limit ${limit}
  `);

  return rows.map(mapTaskUpdateRow);
}

export async function getRecentScopedTaskUpdates(scope: TeamTaskScope, limit = 15): Promise<TeamTaskUpdate[]> {
  if (!(await hasTeamTasksTables())) {
    return [];
  }

  const tasks = await getScopedTeamTasks(scope, { includeCompleted: true });
  if (tasks.length === 0) {
    return [];
  }

  const taskIdsSql = buildUuidJoin(tasks.map((task) => task.id));
  const organization = await requireOrganization();
  const rows = await prisma.$queryRaw<TeamTaskUpdateRow[]>(Prisma.sql`
    select
      ttu.id::text as id,
      ttu.team_task_id::text as team_task_id,
      ttu.organization_id::text as organization_id,
      ttu.author_user_id::text as author_user_id,
      ttu.update_type,
      ttu.message,
      ttu.previous_status,
      ttu.next_status,
      ttu.previous_progress,
      ttu.next_progress,
      ttu.created_at,
      author.full_name as author_full_name,
      author.email as author_email
    from public.team_task_updates ttu
    left join public.profiles author
      on author.id = ttu.author_user_id
    where ttu.organization_id = ${organization.id}::uuid
      and ttu.team_task_id in (${taskIdsSql})
    order by ttu.created_at desc
    limit ${limit}
  `);

  return rows.map(mapTaskUpdateRow);
}

export async function getTeamWorkloadSummary(scope: TeamTaskScope): Promise<TeamWorkloadSummary> {
  const tasks = await getScopedTeamTasks(scope, { includeCompleted: true });
  const memberSnapshots = await getMemberWorkProgressSnapshots(scope);
  const activeTasks = tasks.filter((task) => task.status !== "cancelled");
  const doneTaskCount = tasks.filter((task) => task.status === "done").length;

  return {
    teamTaskCount: activeTasks.length,
    overdueTaskCount: tasks.filter((task) => task.status !== "done" && task.status !== "cancelled" && task.due_date && new Date(task.due_date) < new Date()).length,
    blockedTaskCount: tasks.filter((task) => task.status === "blocked").length,
    doneTaskCount,
    noActivityMemberCount: memberSnapshots.filter((snapshot) => snapshot.recentActivityCount === 0).length,
    completionRate: activeTasks.length > 0 ? Math.round((doneTaskCount / activeTasks.length) * 100) : 0,
  };
}

export async function getMemberWorkProgressSnapshots(scope: TeamTaskScope): Promise<MemberWorkProgressSnapshot[]> {
  const organization = await requireOrganization();
  const members = (await getTeamMembers())
    .filter((member) => scope.visibleUserIds.includes(member.id))
    .filter((member) => member.is_active);

  if (members.length === 0) {
    return [];
  }

  const idsSql = buildUuidJoin(members.map((member) => member.id));
  const hasTaskTables = await hasTeamTasksTables();
  const [tasks, companies, interactions, followups, helpRequests, activityRows] = await Promise.all([
    hasTaskTables
      ? prisma.$queryRaw<Array<{ assigned_to: string | null; created_by: string; status: TeamTaskStatus; progress_percent: number; due_date: Date | null }>>(Prisma.sql`
          select
            assigned_to::text as assigned_to,
            created_by::text as created_by,
            status,
            progress_percent,
            due_date
          from public.team_tasks
          where organization_id = ${organization.id}::uuid
            and (
              assigned_to in (${idsSql})
              or created_by in (${idsSql})
            )
        `)
      : Promise.resolve([]),
    prisma.$queryRaw<Array<{ assigned_user_id: string | null }>>(Prisma.sql`
      select assigned_user_id::text as assigned_user_id
      from public.companies
      where organization_id = ${organization.id}::uuid
        and status <> 'archived'
        and assigned_user_id in (${idsSql})
    `),
    prisma.$queryRaw<Array<{ assigned_user_id: string | null }>>(Prisma.sql`
      select assigned_user_id::text as assigned_user_id
      from public.interactions
      where organization_id = ${organization.id}::uuid
        and status <> 'archived'
        and assigned_user_id in (${idsSql})
        and meeting_datetime >= now() - interval '30 day'
    `),
    prisma.$queryRaw<Array<{ assigned_user_id: string | null; status: string }>>(Prisma.sql`
      select assigned_user_id::text as assigned_user_id, status
      from public.followups
      where organization_id = ${organization.id}::uuid
        and status <> 'archived'
        and assigned_user_id in (${idsSql})
    `),
    prisma.$queryRaw<Array<{ assigned_to: string | null; status: string | null }>>(Prisma.sql`
      select assigned_to::text as assigned_to, status
      from public.help_requests
      where organization_id = ${organization.id}::uuid
        and status <> 'archived'
        and assigned_to in (${idsSql})
    `),
    prisma.$queryRaw<Array<{ actor_user_id: string | null; count: bigint }>>(Prisma.sql`
      select actor_user_id::text as actor_user_id, count(*)::bigint as count
      from public.activity_logs
      where organization_id = ${organization.id}::uuid
        and actor_user_id in (${idsSql})
        and created_at >= now() - interval '7 day'
      group by actor_user_id
    `),
  ]);

  const activityMap = new Map(activityRows.map((row) => [row.actor_user_id ?? "", Number(row.count ?? 0)]));

  return members.map((member) => {
    const assignedTasks = tasks.filter((task) => task.assigned_to === member.id || (!task.assigned_to && task.created_by === member.id));
    const openTasks = assignedTasks.filter((task) => task.status !== "done" && task.status !== "cancelled");
    const completedTaskCount = assignedTasks.filter((task) => task.status === "done").length;
    const averageProgress = assignedTasks.length > 0
      ? Math.round(assignedTasks.reduce((sum, task) => sum + Number(task.progress_percent ?? 0), 0) / assignedTasks.length)
      : 0;

    return {
      userId: member.id,
      name: member.full_name ?? member.email,
      email: member.email,
      roleName: member.role_name ?? null,
      managerName: member.manager_name ?? member.manager_email ?? null,
      teamTaskCount: assignedTasks.length,
      todoTaskCount: assignedTasks.filter((task) => task.status === "todo").length,
      inProgressTaskCount: assignedTasks.filter((task) => task.status === "in_progress").length,
      blockedTaskCount: assignedTasks.filter((task) => task.status === "blocked").length,
      overdueTaskCount: openTasks.filter((task) => task.due_date && task.due_date < new Date()).length,
      completedTaskCount,
      averageProgress,
      assignedCompanies: companies.filter((row) => row.assigned_user_id === member.id).length,
      scheduledMeetings: interactions.filter((row) => row.assigned_user_id === member.id).length,
      pendingFollowups: followups.filter((row) => row.assigned_user_id === member.id && row.status === "pending").length,
      openHelpRequests: helpRequests.filter((row) => row.assigned_to === member.id && row.status !== "resolved").length,
      recentActivityCount: activityMap.get(member.id) ?? 0,
    };
  });
}

export async function getMyWorkSummary() {
  const scope = await resolveTeamTaskScope();
  const [profile, tasks, recentUpdates, memberSnapshots] = await Promise.all([
    getCurrentProfile(),
    getScopedTeamTasks(scope, {
      assigneeId: scope.currentUserId,
      includeCompleted: true,
    }),
    getRecentScopedTaskUpdates(scope, 10),
    getMemberWorkProgressSnapshots(scope),
  ]);

  return {
    profile,
    tasks,
    recentUpdates,
    snapshot: memberSnapshots.find((item) => item.userId === scope.currentUserId) ?? null,
    scope,
  };
}
