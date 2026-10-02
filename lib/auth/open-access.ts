import "server-only";

import { prisma } from "@/lib/prisma";
import { createWorkspaceForUser, resolveActiveWorkspaceIdForUser } from "@/lib/workspace/service";

const OPEN_ACCESS_EMAIL = "open-access@crm.local";
let setupPromise: Promise<{ id: string; email: string; name: string | null }> | null = null;

export function isOpenAccessEnabled() {
  return process.env.OPEN_ACCESS_ENABLED !== "false";
}

async function setupOpenAccessUser() {
  const user = await prisma.user.upsert({
    where: { email: OPEN_ACCESS_EMAIL },
    update: { is_active: true },
    create: {
      email: OPEN_ACCESS_EMAIL,
      name: "Workspace User",
      is_active: true,
      is_super_admin: false,
    },
    select: { id: true, email: true, name: true },
  });

  if (!(await resolveActiveWorkspaceIdForUser(user.id))) {
    await createWorkspaceForUser(user.id, { name: "Open CRM Workspace", companySize: "" });
  }

  return user;
}

export async function getOpenAccessUser() {
  if (!isOpenAccessEnabled()) return null;

  setupPromise ??= setupOpenAccessUser().catch((error) => {
    setupPromise = null;
    throw error;
  });
  return setupPromise;
}
