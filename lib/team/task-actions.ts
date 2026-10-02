"use server";

import { revalidatePath } from "next/cache";
import { Prisma } from "@prisma/client";
import { z } from "zod";
import { getCurrentProfile, hasPermission, requireAuth, requireOrganization } from "@/lib/auth/session";
import { getSafeErrorMessage, logServerError } from "@/lib/errors";
import { createWorkspaceNotification } from "@/lib/notifications/notifications";
import { prisma } from "@/lib/prisma";
import { ensureCanManageTaskAssignee, getManageableTeamMemberIds } from "@/lib/team/hierarchy";
import { hasTeamTasksTables, isTeamTasksRelationMissingError } from "@/lib/team/task-support";
import { TEAM_TASK_PRIORITIES, TEAM_TASK_RELATED_ENTITY_TYPES, TEAM_TASK_STATUSES, type TeamTaskStatus } from "@/lib/team/types";

type TeamTaskRecord = {
  id: string;
  organization_id: string;
  title: string;
  status: TeamTaskStatus;
  progress_percent: number;
  created_by: string;
  assigned_to: string | null;
  manager_owner_id: string | null;
};

const createTaskSchema = z.object({
  title: z.string().trim().min(3, "Task title must be at least 3 characters."),
  description: z.string().trim().max(1200).optional(),
  assignedTo: z.string().uuid().optional().nullable(),
  priority: z.enum(TEAM_TASK_PRIORITIES).default("medium"),
  startDate: z.string().optional().nullable(),
  dueDate: z.string().optional().nullable(),
  relatedEntityType: z.enum(TEAM_TASK_RELATED_ENTITY_TYPES).optional().nullable(),
  relatedEntityId: z.string().uuid().optional().nullable(),
});

const progressSchema = z.object({
  progressPercent: z.coerce.number().int().min(0).max(100),
  message: z.string().trim().max(500).optional(),
});

const statusSchema = z.object({
  status: z.enum(TEAM_TASK_STATUSES),
  message: z.string().trim().max(500).optional(),
});

const commentSchema = z.object({
  message: z.string().trim().min(1, "Update note is required.").max(1200),
});

const assignSchema = z.object({
  assignedTo: z.string().uuid().nullable(),
});

function optionalDate(value?: string | null) {
  if (!value) {
    return null;
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error("Invalid date value.");
  }

  return value;
}

async function insertTimelineUpdate(input: {
  taskId: string;
  organizationId: string;
  authorUserId: string | null;
  updateType: "created" | "assigned" | "status_changed" | "progress_changed" | "commented" | "completed" | "reopened" | "cancelled";
  message?: string | null;
  previousStatus?: string | null;
  nextStatus?: string | null;
  previousProgress?: number | null;
  nextProgress?: number | null;
}) {
  await prisma.$executeRaw`
    insert into public.team_task_updates (
      team_task_id,
      organization_id,
      author_user_id,
      update_type,
      message,
      previous_status,
      next_status,
      previous_progress,
      next_progress
    )
    values (
      ${input.taskId}::uuid,
      ${input.organizationId}::uuid,
      ${input.authorUserId ?? null}::uuid,
      ${input.updateType},
      nullif(${input.message ?? null}, ''),
      ${input.previousStatus ?? null},
      ${input.nextStatus ?? null},
      ${input.previousProgress ?? null},
      ${input.nextProgress ?? null}
    )
  `;
}

async function getTaskRecord(taskId: string, organizationId: string): Promise<TeamTaskRecord | null> {
  const rows = await prisma.$queryRaw<TeamTaskRecord[]>`
    select
      id::text as id,
      organization_id::text as organization_id,
      title,
      status,
      progress_percent,
      created_by::text as created_by,
      assigned_to::text as assigned_to,
      manager_owner_id::text as manager_owner_id
    from public.team_tasks
    where id = ${taskId}::uuid
      and organization_id = ${organizationId}::uuid
    limit 1
  `;

  return rows[0] ?? null;
}

async function canManageTaskRecord(task: TeamTaskRecord, actorUserId: string) {
  if (await hasPermission("team.tasks.manage_all") || await hasPermission("settings.manage")) {
    return true;
  }

  if (task.created_by === actorUserId || task.assigned_to === actorUserId || task.manager_owner_id === actorUserId) {
    return true;
  }

  if (!(await hasPermission("team.tasks.assign"))) {
    return false;
  }

  const manageableIds = await getManageableTeamMemberIds({ includeSelf: true, includeDescendants: true });
  return [
    task.created_by,
    task.assigned_to,
    task.manager_owner_id,
  ].some((value) => value && manageableIds.includes(value));
}

async function ensureCanManageTask(task: TeamTaskRecord, actorUserId: string) {
  const allowed = await canManageTaskRecord(task, actorUserId);
  if (!allowed) {
    throw new Error("You do not have permission to manage this task.");
  }
}

function resolveTaskManagerOwner(input: {
  actorUserId: string;
  actorManagerUserId?: string | null;
  assignedTo?: string | null;
  canAssignTasks: boolean;
}) {
  if (input.assignedTo && input.assignedTo !== input.actorUserId && input.canAssignTasks) {
    return input.actorUserId;
  }

  return input.actorManagerUserId ?? input.actorUserId;
}

function revalidateTaskPaths() {
  revalidatePath("/team");
  revalidatePath("/team-dashboard");
  revalidatePath("/reports");
  revalidatePath("/my-work");
}

export async function createTeamTask(input: unknown) {
  if (!(await hasTeamTasksTables())) {
    throw new Error("Team work tasks are not ready yet. Please apply the latest database migration first.");
  }

  const parsed = createTaskSchema.safeParse(input);
  if (!parsed.success) {
    throw new Error(parsed.error.errors[0]?.message ?? "Please review the task form and try again.");
  }

  const [user, profile, organization, canAssignPermission, canManageAllTasks] = await Promise.all([
    requireAuth(),
    getCurrentProfile(),
    requireOrganization(),
    hasPermission("team.tasks.assign"),
    hasPermission("team.tasks.manage_all").then((allowed) => allowed || hasPermission("settings.manage")),
  ]);
  const canAssignTasks = Boolean(canAssignPermission || canManageAllTasks);

  const assignedTo = parsed.data.assignedTo ?? user.id;
  if (assignedTo !== user.id) {
    await ensureCanManageTaskAssignee(assignedTo);
  }

  const managerOwnerId = resolveTaskManagerOwner({
    actorUserId: user.id,
    actorManagerUserId: profile?.manager_user_id ?? null,
    assignedTo,
    canAssignTasks: Boolean(canAssignTasks),
  });

  try {
    const rows = await prisma.$queryRaw<Array<{ id: string }>>(Prisma.sql`
      insert into public.team_tasks (
        organization_id,
        title,
        description,
        status,
        priority,
        progress_percent,
        start_date,
        due_date,
        created_by,
        assigned_to,
        manager_owner_id,
        related_entity_type,
        related_entity_id
      )
      values (
        ${organization.id}::uuid,
        ${parsed.data.title},
        nullif(${parsed.data.description ?? null}, ''),
        'todo',
        ${parsed.data.priority},
        0,
        ${optionalDate(parsed.data.startDate ?? null)}::date,
        ${optionalDate(parsed.data.dueDate ?? null)}::date,
        ${user.id}::uuid,
        ${assignedTo}::uuid,
        ${managerOwnerId}::uuid,
        ${parsed.data.relatedEntityType ?? null},
        ${parsed.data.relatedEntityId ?? null}::uuid
      )
      returning id::text as id
    `);

    const taskId = rows[0]?.id;
    if (!taskId) {
      throw new Error("Unable to create the task right now.");
    }

    await insertTimelineUpdate({
      taskId,
      organizationId: organization.id,
      authorUserId: user.id,
      updateType: "created",
      message: parsed.data.description ?? null,
      nextStatus: "todo",
      nextProgress: 0,
    });

    if (assignedTo && assignedTo !== user.id) {
      await createWorkspaceNotification({
        userId: assignedTo,
        type: "team_task.assigned",
        title: "New team task assigned",
        message: parsed.data.title,
        link: "/my-work",
      });
    }

    revalidateTaskPaths();
    return { ok: true, id: taskId };
  } catch (error) {
    if (isTeamTasksRelationMissingError(error)) {
      throw new Error("Team work tasks are not ready yet. Please apply the latest database migration first.");
    }
    logServerError("team_task.create", error, { assignedTo, title: parsed.data.title });
    throw new Error(getSafeErrorMessage(error, "Unable to create the task right now."));
  }
}

export async function updateTeamTaskAssignment(taskId: string, input: unknown) {
  if (!(await hasTeamTasksTables())) {
    throw new Error("Team work tasks are not ready yet. Please apply the latest database migration first.");
  }

  const parsed = assignSchema.safeParse(input);
  if (!parsed.success) {
    throw new Error(parsed.error.errors[0]?.message ?? "Invalid task assignment.");
  }

  const [user, organization] = await Promise.all([requireAuth(), requireOrganization()]);
  const task = await getTaskRecord(taskId, organization.id);
  if (!task) {
    throw new Error("Task was not found.");
  }

  await ensureCanManageTask(task, user.id);
  const [canAssignTasks, canManageAllTasks] = await Promise.all([
    hasPermission("team.tasks.assign"),
    hasPermission("team.tasks.manage_all").then((allowed) => allowed || hasPermission("settings.manage")),
  ]);

  if (!(canAssignTasks || canManageAllTasks)) {
    throw new Error("You do not have permission to reassign tasks.");
  }

  if (parsed.data.assignedTo) {
    await ensureCanManageTaskAssignee(parsed.data.assignedTo);
  }

  await prisma.$executeRaw`
    update public.team_tasks
    set
      assigned_to = ${parsed.data.assignedTo ?? null}::uuid,
      manager_owner_id = ${user.id}::uuid,
      updated_at = now()
    where id = ${taskId}::uuid
      and organization_id = ${organization.id}::uuid
  `;

  await insertTimelineUpdate({
    taskId,
    organizationId: organization.id,
    authorUserId: user.id,
    updateType: "assigned",
    message: parsed.data.assignedTo ? "Task assignee updated." : "Task unassigned.",
  });

  if (parsed.data.assignedTo && parsed.data.assignedTo !== user.id) {
    await createWorkspaceNotification({
      userId: parsed.data.assignedTo,
      type: "team_task.assigned",
      title: "Task assignment updated",
      message: task.title,
      link: "/my-work",
    });
  }

  revalidateTaskPaths();
  return { ok: true };
}

export async function updateTeamTaskStatus(taskId: string, input: unknown) {
  if (!(await hasTeamTasksTables())) {
    throw new Error("Team work tasks are not ready yet. Please apply the latest database migration first.");
  }

  const parsed = statusSchema.safeParse(input);
  if (!parsed.success) {
    throw new Error(parsed.error.errors[0]?.message ?? "Invalid task status.");
  }

  const [user, organization] = await Promise.all([requireAuth(), requireOrganization()]);
  const task = await getTaskRecord(taskId, organization.id);
  if (!task) {
    throw new Error("Task was not found.");
  }

  await ensureCanManageTask(task, user.id);

  const nextProgress = parsed.data.status === "done" ? 100 : task.progress_percent;
  const completedAt = parsed.data.status === "done" ? Prisma.sql`now()` : Prisma.sql`null`;

  await prisma.$executeRaw(Prisma.sql`
    update public.team_tasks
    set
      status = ${parsed.data.status},
      progress_percent = ${nextProgress},
      completed_at = ${completedAt},
      updated_at = now()
    where id = ${taskId}::uuid
      and organization_id = ${organization.id}::uuid
  `);

  await insertTimelineUpdate({
    taskId,
    organizationId: organization.id,
    authorUserId: user.id,
    updateType:
      parsed.data.status === "done"
        ? "completed"
        : parsed.data.status === "cancelled"
          ? "cancelled"
          : task.status === "done"
            ? "reopened"
            : "status_changed",
    message: parsed.data.message ?? null,
    previousStatus: task.status,
    nextStatus: parsed.data.status,
    previousProgress: task.progress_percent,
    nextProgress,
  });

  revalidateTaskPaths();
  return { ok: true };
}

export async function updateTeamTaskProgress(taskId: string, input: unknown) {
  if (!(await hasTeamTasksTables())) {
    throw new Error("Team work tasks are not ready yet. Please apply the latest database migration first.");
  }

  const parsed = progressSchema.safeParse(input);
  if (!parsed.success) {
    throw new Error(parsed.error.errors[0]?.message ?? "Invalid task progress value.");
  }

  const [user, organization] = await Promise.all([requireAuth(), requireOrganization()]);
  const task = await getTaskRecord(taskId, organization.id);
  if (!task) {
    throw new Error("Task was not found.");
  }

  await ensureCanManageTask(task, user.id);

  const nextStatus = parsed.data.progressPercent >= 100 ? "done" : task.status === "todo" && parsed.data.progressPercent > 0 ? "in_progress" : task.status;
  const completedAt = parsed.data.progressPercent >= 100 ? Prisma.sql`now()` : Prisma.sql`null`;

  await prisma.$executeRaw(Prisma.sql`
    update public.team_tasks
    set
      progress_percent = ${parsed.data.progressPercent},
      status = ${nextStatus},
      completed_at = ${completedAt},
      updated_at = now()
    where id = ${taskId}::uuid
      and organization_id = ${organization.id}::uuid
  `);

  await insertTimelineUpdate({
    taskId,
    organizationId: organization.id,
    authorUserId: user.id,
    updateType: parsed.data.progressPercent >= 100 ? "completed" : "progress_changed",
    message: parsed.data.message ?? null,
    previousStatus: task.status,
    nextStatus,
    previousProgress: task.progress_percent,
    nextProgress: parsed.data.progressPercent,
  });

  revalidateTaskPaths();
  return { ok: true };
}

export async function addTeamTaskComment(taskId: string, input: unknown) {
  if (!(await hasTeamTasksTables())) {
    throw new Error("Team work tasks are not ready yet. Please apply the latest database migration first.");
  }

  const parsed = commentSchema.safeParse(input);
  if (!parsed.success) {
    throw new Error(parsed.error.errors[0]?.message ?? "Invalid task update.");
  }

  const [user, organization] = await Promise.all([requireAuth(), requireOrganization()]);
  const task = await getTaskRecord(taskId, organization.id);
  if (!task) {
    throw new Error("Task was not found.");
  }

  await ensureCanManageTask(task, user.id);

  await insertTimelineUpdate({
    taskId,
    organizationId: organization.id,
    authorUserId: user.id,
    updateType: "commented",
    message: parsed.data.message,
    previousStatus: task.status,
    nextStatus: task.status,
    previousProgress: task.progress_percent,
    nextProgress: task.progress_percent,
  });

  revalidateTaskPaths();
  return { ok: true };
}

export async function deleteTeamTask(taskId: string) {
  if (!(await hasTeamTasksTables())) {
    throw new Error("Team work tasks are not ready yet. Please apply the latest database migration first.");
  }

  const [user, organization] = await Promise.all([requireAuth(), requireOrganization()]);
  const task = await getTaskRecord(taskId, organization.id);
  if (!task) {
    throw new Error("Task was not found.");
  }

  if (!(await hasPermission("team.tasks.manage_all") || await hasPermission("settings.manage") || task.created_by === user.id || task.manager_owner_id === user.id)) {
    throw new Error("You do not have permission to delete this task.");
  }

  await prisma.$executeRaw`
    delete from public.team_tasks
    where id = ${taskId}::uuid
      and organization_id = ${organization.id}::uuid
  `;

  revalidateTaskPaths();
  return { ok: true };
}
