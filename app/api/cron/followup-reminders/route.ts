import { type NextRequest, NextResponse } from "next/server";
import { getDueFollowupReminders, sendFollowupReminderEmail } from "@/lib/crm/reminder-helpers";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  const cronSecret = process.env.CRON_SECRET;
  const urlSecret = request.nextUrl.searchParams.get("secret");

  // Basic security check
  if (cronSecret && authHeader !== `Bearer ${cronSecret}` && urlSecret !== cronSecret) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const dueReminders = await getDueFollowupReminders();
    const results = [];

    for (const reminder of dueReminders) {
      const success = await sendFollowupReminderEmail(reminder);
      results.push({ id: reminder.id, success });
    }

    return NextResponse.json({
      processed: dueReminders.length,
      results,
    });
  } catch (error: any) {
    console.error("Cron Error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
