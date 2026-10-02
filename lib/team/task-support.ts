import "server-only";

import { cache } from "react";
import { Prisma } from "@prisma/client";
import { prisma } from "@/lib/prisma";

export function isTeamTasksRelationMissingError(error: unknown) {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError
    && error.code === "P2010"
    && error.message.includes("42P01")
    && (
      error.message.includes("team_tasks")
      || error.message.includes("team_task_updates")
    )
  );
}

export const hasTeamTasksTables = cache(async () => {
  try {
    const rows = await prisma.$queryRaw<Array<{ tasks_exists: string | null; updates_exists: string | null }>>`
      select
        to_regclass('public.team_tasks')::text as tasks_exists,
        to_regclass('public.team_task_updates')::text as updates_exists
    `;

    return Boolean(rows[0]?.tasks_exists && rows[0]?.updates_exists);
  } catch {
    return false;
  }
});
