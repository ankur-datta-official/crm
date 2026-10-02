"use client";

import type { Dispatch, ReactNode, SetStateAction } from "react";
import { useEffect, useMemo, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { CheckCircle2, ListChecks, MessageSquare, Plus, Target, Users } from "lucide-react";
import { addTeamTaskComment, createTeamTask, deleteTeamTask, updateTeamTaskAssignment, updateTeamTaskProgress, updateTeamTaskStatus } from "@/lib/team/task-actions";
import type { MemberWorkProgressSnapshot, TeamTask, TeamTaskPriority, TeamTaskStatus, TeamTaskUpdate, TeamWorkloadSummary } from "@/lib/team/types";
import type { TeamMember } from "@/lib/team/types";
import { TEAM_TASK_PRIORITIES, TEAM_TASK_STATUSES } from "@/lib/team/types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { formatDateBD, formatDateTimeBD } from "@/lib/format/datetime";
import { getDisplayName } from "@/lib/utils";

type TeamWorkspacePanelProps = {
  mode: "team" | "self";
  tasks: TeamTask[];
  recentUpdates: TeamTaskUpdate[];
  memberSnapshots: MemberWorkProgressSnapshot[];
  summary: TeamWorkloadSummary;
  members: TeamMember[];
  currentUserId: string;
  canAssignTasks: boolean;
};

type NewTaskFormState = {
  title: string;
  description: string;
  assignedTo: string;
  priority: TeamTaskPriority;
  startDate: string;
  dueDate: string;
};

const DEFAULT_FORM_STATE: NewTaskFormState = {
  title: "",
  description: "",
  assignedTo: "",
  priority: "medium",
  startDate: "",
  dueDate: "",
};

function getStatusBadgeVariant(status: TeamTaskStatus) {
  switch (status) {
    case "done":
      return "success" as const;
    case "blocked":
      return "destructive" as const;
    case "in_progress":
      return "info" as const;
    case "cancelled":
      return "secondary" as const;
    default:
      return "warning" as const;
  }
}

function getPriorityBadgeVariant(priority: TeamTaskPriority) {
  switch (priority) {
    case "urgent":
      return "destructive" as const;
    case "high":
      return "warning" as const;
    case "medium":
      return "info" as const;
    default:
      return "secondary" as const;
  }
}

function ProgressBar({ value }: { value: number }) {
  return (
    <div className="h-2.5 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-800">
      <div
        className="h-full rounded-full bg-gradient-to-r from-sky-500 via-cyan-500 to-emerald-500"
        style={{ width: `${Math.max(0, Math.min(100, value))}%` }}
      />
    </div>
  );
}

export function TeamWorkspacePanel({
  mode,
  tasks,
  recentUpdates,
  memberSnapshots,
  summary,
  members,
  currentUserId,
  canAssignTasks,
}: TeamWorkspacePanelProps) {
  const router = useRouter();
  const isMountedRef = useRef(false);
  const [isPending, startTransition] = useTransition();
  const [search, setSearch] = useState("");
  const [assigneeFilter, setAssigneeFilter] = useState(mode === "self" ? currentUserId : "all");
  const [statusFilter, setStatusFilter] = useState<"all" | TeamTaskStatus>("all");
  const [priorityFilter, setPriorityFilter] = useState<"all" | TeamTaskPriority>("all");
  const [selectedMemberId, setSelectedMemberId] = useState(memberSnapshots[0]?.userId ?? currentUserId);
  const [taskDialogOpen, setTaskDialogOpen] = useState(false);
  const [newTask, setNewTask] = useState<NewTaskFormState>({
    ...DEFAULT_FORM_STATE,
    assignedTo: mode === "self" ? currentUserId : "",
  });
  const [error, setError] = useState<string | null>(null);
  const [commentDrafts, setCommentDrafts] = useState<Record<string, string>>({});
  const [progressDrafts, setProgressDrafts] = useState<Record<string, string>>({});
  const [statusDrafts, setStatusDrafts] = useState<Record<string, TeamTaskStatus>>({});
  const [assigneeDrafts, setAssigneeDrafts] = useState<Record<string, string>>({});

  useEffect(() => {
    isMountedRef.current = true;
    return () => {
      isMountedRef.current = false;
    };
  }, []);

  const memberOptions = useMemo(
    () => members.filter((member) => member.is_active).map((member) => ({
      id: member.id,
      label: getDisplayName(member.full_name, member.email),
      email: member.email,
    })),
    [members],
  );

  const filteredTasks = useMemo(() => {
    const query = search.trim().toLowerCase();
    return tasks.filter((task) => {
      const matchesSearch = !query
        || task.title.toLowerCase().includes(query)
        || task.description?.toLowerCase().includes(query)
        || task.assignee?.full_name?.toLowerCase().includes(query)
        || task.assignee?.email.toLowerCase().includes(query);
      const matchesAssignee = assigneeFilter === "all" || task.assigned_to === assigneeFilter || (!task.assigned_to && assigneeFilter === task.created_by);
      const matchesStatus = statusFilter === "all" || task.status === statusFilter;
      const matchesPriority = priorityFilter === "all" || task.priority === priorityFilter;
      return matchesSearch && matchesAssignee && matchesStatus && matchesPriority;
    });
  }, [assigneeFilter, priorityFilter, search, statusFilter, tasks]);

  const selectedSnapshot = memberSnapshots.find((snapshot) => snapshot.userId === selectedMemberId) ?? memberSnapshots[0] ?? null;
  const selectedMemberTasks = filteredTasks.filter((task) => {
    if (!selectedSnapshot) {
      return false;
    }

    return task.assigned_to === selectedSnapshot.userId || (!task.assigned_to && task.created_by === selectedSnapshot.userId);
  });
  const selectedMemberUpdates = recentUpdates.filter((update) => selectedMemberTasks.some((task) => task.id === update.team_task_id)).slice(0, 8);

  function runMutation(work: () => Promise<void>) {
    startTransition(async () => {
      try {
        setError(null);
        await work();
        if (isMountedRef.current) {
          router.refresh();
        }
      } catch (mutationError) {
        if (isMountedRef.current) {
          setError(mutationError instanceof Error ? mutationError.message : "Unable to complete this work update.");
        }
      }
    });
  }

  return (
    <div className="space-y-5">
      {error ? (
        <div className="rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700 dark:border-rose-500/20 dark:bg-rose-500/10 dark:text-rose-200">
          {error}
        </div>
      ) : null}

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-5">
        <SummaryCard title="Active Workload" value={String(summary.teamTaskCount)} helper="Open internal tasks in scope" icon={<ListChecks className="size-5" />} tone="blue" />
        <SummaryCard title="Overdue Tasks" value={String(summary.overdueTaskCount)} helper="Need follow-through first" icon={<Target className="size-5" />} tone="orange" />
        <SummaryCard title="Blocked Tasks" value={String(summary.blockedTaskCount)} helper="Stuck tasks requiring support" icon={<MessageSquare className="size-5" />} tone="rose" />
        <SummaryCard title="No Activity Members" value={String(summary.noActivityMemberCount)} helper="No recent logged activity" icon={<Users className="size-5" />} tone="slate" />
        <SummaryCard title="Completion Rate" value={`${summary.completionRate}%`} helper={`${summary.doneTaskCount} done tasks`} icon={<CheckCircle2 className="size-5" />} tone="emerald" />
      </div>

      <Card>
        <CardHeader className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <CardTitle>{mode === "team" ? "Work Management" : "My Work"}</CardTitle>
            <CardDescription>
              {mode === "team"
                ? "Track team workload, assign internal tasks, and monitor progress next to existing CRM work."
                : "Update your assigned tasks, log progress, and keep your manager aligned."}
            </CardDescription>
          </div>
          <CreateTaskDialog
            open={taskDialogOpen}
            onOpenChange={setTaskDialogOpen}
            form={newTask}
            setForm={setNewTask}
            members={memberOptions}
            canAssignTasks={canAssignTasks}
            currentUserId={currentUserId}
            isPending={isPending}
            onSubmit={() => runMutation(async () => {
              await createTeamTask({
                title: newTask.title,
                description: newTask.description,
                assignedTo: newTask.assignedTo || currentUserId,
                priority: newTask.priority,
                startDate: newTask.startDate || null,
                dueDate: newTask.dueDate || null,
              });
              if (isMountedRef.current) {
                setTaskDialogOpen(false);
                setNewTask({
                  ...DEFAULT_FORM_STATE,
                  assignedTo: mode === "self" ? currentUserId : "",
                });
              }
            })}
          />
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid gap-3 lg:grid-cols-4">
            <Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search tasks, assignee, or description" />
            <select className="crm-filter-select" value={assigneeFilter} onChange={(event) => setAssigneeFilter(event.target.value)}>
              <option value="all">All assignees</option>
              {memberOptions.map((member) => (
                <option key={member.id} value={member.id}>{member.label}</option>
              ))}
            </select>
            <select className="crm-filter-select" value={statusFilter} onChange={(event) => setStatusFilter(event.target.value as TeamTaskStatus | "all")}>
              <option value="all">All statuses</option>
              {TEAM_TASK_STATUSES.map((status) => (
                <option key={status} value={status}>{status.replaceAll("_", " ")}</option>
              ))}
            </select>
            <select className="crm-filter-select" value={priorityFilter} onChange={(event) => setPriorityFilter(event.target.value as TeamTaskPriority | "all")}>
              <option value="all">All priorities</option>
              {TEAM_TASK_PRIORITIES.map((priority) => (
                <option key={priority} value={priority}>{priority}</option>
              ))}
            </select>
          </div>

          {filteredTasks.length === 0 ? (
            <div className="rounded-2xl border border-dashed px-5 py-8 text-center text-sm text-muted-foreground">
              No tasks matched the current filters.
            </div>
          ) : (
            <div className="grid gap-4 xl:grid-cols-[minmax(0,1.4fr)_minmax(300px,0.9fr)]">
              <div className="space-y-4">
                {filteredTasks.map((task) => {
                  const canEditTask = canAssignTasks || task.created_by === currentUserId || task.assigned_to === currentUserId || task.manager_owner_id === currentUserId;
                  return (
                    <div key={task.id} className="rounded-2xl border border-border/70 bg-white/95 p-4 shadow-sm dark:border-slate-800 dark:bg-slate-950/70">
                      <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
                        <div className="space-y-2">
                          <div className="flex flex-wrap items-center gap-2">
                            <h3 className="text-base font-semibold text-slate-900 dark:text-slate-100">{task.title}</h3>
                            <Badge variant={getStatusBadgeVariant(task.status)}>{task.status.replaceAll("_", " ")}</Badge>
                            <Badge variant={getPriorityBadgeVariant(task.priority)}>{task.priority}</Badge>
                          </div>
                          <p className="text-sm text-muted-foreground">{task.description ?? "No description provided."}</p>
                          <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-slate-500 dark:text-slate-400">
                            <span>Assignee: {task.assignee ? getDisplayName(task.assignee.full_name, task.assignee.email) : "Unassigned"}</span>
                            <span>Creator: {task.creator ? getDisplayName(task.creator.full_name, task.creator.email) : "Unknown"}</span>
                            <span>Due: {task.due_date ? formatDateBD(task.due_date) : "No due date"}</span>
                          </div>
                        </div>
                        {canEditTask ? (
                          <Button
                            type="button"
                            variant="outline"
                            size="sm"
                            disabled={isPending}
                            onClick={() => runMutation(async () => {
                              await deleteTeamTask(task.id);
                            })}
                          >
                            Delete
                          </Button>
                        ) : null}
                      </div>

                      <div className="mt-4 space-y-2">
                        <div className="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
                          <span>Progress</span>
                          <span>{task.progress_percent}%</span>
                        </div>
                        <ProgressBar value={task.progress_percent} />
                      </div>

                      {canEditTask ? (
                        <div className="mt-4 grid gap-3 lg:grid-cols-4">
                          <div>
                            <label className="mb-1 block text-xs font-medium uppercase tracking-[0.14em] text-slate-400">Status</label>
                            <select
                              className="crm-filter-select"
                              value={statusDrafts[task.id] ?? task.status}
                              onChange={(event) => setStatusDrafts((current) => ({ ...current, [task.id]: event.target.value as TeamTaskStatus }))}
                            >
                              {TEAM_TASK_STATUSES.map((status) => (
                                <option key={status} value={status}>{status.replaceAll("_", " ")}</option>
                              ))}
                            </select>
                            <Button
                              type="button"
                              size="sm"
                              className="mt-2 w-full"
                              disabled={isPending}
                              onClick={() => runMutation(async () => {
                                await updateTeamTaskStatus(task.id, { status: statusDrafts[task.id] ?? task.status });
                              })}
                            >
                              Save status
                            </Button>
                          </div>

                          <div>
                            <label className="mb-1 block text-xs font-medium uppercase tracking-[0.14em] text-slate-400">Progress %</label>
                            <Input
                              type="number"
                              min={0}
                              max={100}
                              value={progressDrafts[task.id] ?? String(task.progress_percent)}
                              onChange={(event) => setProgressDrafts((current) => ({ ...current, [task.id]: event.target.value }))}
                            />
                            <Button
                              type="button"
                              size="sm"
                              className="mt-2 w-full"
                              disabled={isPending}
                              onClick={() => runMutation(async () => {
                                await updateTeamTaskProgress(task.id, { progressPercent: Number(progressDrafts[task.id] ?? task.progress_percent) });
                              })}
                            >
                              Save progress
                            </Button>
                          </div>

                          <div>
                            <label className="mb-1 block text-xs font-medium uppercase tracking-[0.14em] text-slate-400">Assignee</label>
                            <select
                              className="crm-filter-select"
                              value={assigneeDrafts[task.id] ?? task.assigned_to ?? ""}
                              onChange={(event) => setAssigneeDrafts((current) => ({ ...current, [task.id]: event.target.value }))}
                              disabled={!canAssignTasks}
                            >
                              <option value="">Unassigned</option>
                              {memberOptions.map((member) => (
                                <option key={member.id} value={member.id}>{member.label}</option>
                              ))}
                            </select>
                            <Button
                              type="button"
                              size="sm"
                              className="mt-2 w-full"
                              disabled={isPending || !canAssignTasks}
                              onClick={() => runMutation(async () => {
                                await updateTeamTaskAssignment(task.id, { assignedTo: assigneeDrafts[task.id] || null });
                              })}
                            >
                              Update assignee
                            </Button>
                          </div>

                          <div>
                            <label className="mb-1 block text-xs font-medium uppercase tracking-[0.14em] text-slate-400">Progress note</label>
                            <textarea
                              className="min-h-[44px] w-full rounded-xl border border-input bg-background px-3 py-2 text-sm text-foreground outline-none transition focus:border-ring dark:border-slate-800 dark:bg-slate-950/85"
                              value={commentDrafts[task.id] ?? ""}
                              onChange={(event) => setCommentDrafts((current) => ({ ...current, [task.id]: event.target.value }))}
                              placeholder="Share a short update"
                            />
                            <Button
                              type="button"
                              size="sm"
                              className="mt-2 w-full"
                              disabled={isPending || !(commentDrafts[task.id] ?? "").trim()}
                              onClick={() => runMutation(async () => {
                                await addTeamTaskComment(task.id, { message: commentDrafts[task.id] });
                                if (isMountedRef.current) {
                                  setCommentDrafts((current) => ({ ...current, [task.id]: "" }));
                                }
                              })}
                            >
                              Add update
                            </Button>
                          </div>
                        </div>
                      ) : null}
                    </div>
                  );
                })}
              </div>

              <div className="space-y-4">
                {mode === "team" ? (
                  <Card>
                    <CardHeader>
                      <CardTitle>Member Workload</CardTitle>
                      <CardDescription>Internal tasks plus assigned CRM workload for each visible team member.</CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-3">
                      <select className="crm-filter-select" value={selectedMemberId} onChange={(event) => setSelectedMemberId(event.target.value)}>
                        {memberSnapshots.map((snapshot) => (
                          <option key={snapshot.userId} value={snapshot.userId}>{snapshot.name}</option>
                        ))}
                      </select>
                      <div className="max-h-[20rem] space-y-3 overflow-y-auto pr-1">
                        {memberSnapshots.map((snapshot) => (
                          <button
                            key={snapshot.userId}
                            type="button"
                            onClick={() => setSelectedMemberId(snapshot.userId)}
                            className={`w-full rounded-2xl border px-4 py-3 text-left transition ${
                              selectedMemberId === snapshot.userId
                                ? "border-emerald-300 bg-emerald-50 dark:border-emerald-500/30 dark:bg-emerald-500/10"
                                : "border-border/70 bg-white dark:border-slate-800 dark:bg-slate-950/50"
                            }`}
                          >
                            <div className="flex items-start justify-between gap-3">
                              <div>
                                <div className="font-medium text-slate-900 dark:text-slate-100">{snapshot.name}</div>
                                <div className="text-xs text-muted-foreground">{snapshot.roleName ?? snapshot.email}</div>
                              </div>
                              <Badge variant={snapshot.overdueTaskCount > 0 ? "warning" : "success"}>
                                {snapshot.teamTaskCount} tasks
                              </Badge>
                            </div>
                            <div className="mt-3 grid grid-cols-2 gap-2 text-xs text-slate-500 dark:text-slate-400">
                              <span>Progress: {snapshot.averageProgress}%</span>
                              <span>Overdue: {snapshot.overdueTaskCount}</span>
                              <span>Companies: {snapshot.assignedCompanies}</span>
                              <span>Follow-ups: {snapshot.pendingFollowups}</span>
                            </div>
                          </button>
                        ))}
                      </div>
                    </CardContent>
                  </Card>
                ) : null}

                <Card>
                  <CardHeader>
                    <CardTitle>{mode === "team" ? "Member Detail" : "My Current Snapshot"}</CardTitle>
                    <CardDescription>
                      {selectedSnapshot
                        ? `${selectedSnapshot.name} is carrying ${selectedSnapshot.teamTaskCount} internal tasks right now.`
                        : "No member workload is available yet."}
                    </CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-3">
                    {selectedSnapshot ? (
                      <>
                        <div className="grid grid-cols-2 gap-3 text-sm">
                          <DetailMetric label="In Progress" value={selectedSnapshot.inProgressTaskCount} />
                          <DetailMetric label="Blocked" value={selectedSnapshot.blockedTaskCount} />
                          <DetailMetric label="Overdue" value={selectedSnapshot.overdueTaskCount} />
                          <DetailMetric label="Recent Activity" value={selectedSnapshot.recentActivityCount} />
                          <DetailMetric label="Meetings" value={selectedSnapshot.scheduledMeetings} />
                          <DetailMetric label="Help Requests" value={selectedSnapshot.openHelpRequests} />
                        </div>

                        <div className="rounded-2xl border border-border/70 bg-slate-50/60 p-3 dark:border-slate-800 dark:bg-slate-950/60">
                          <div className="text-xs uppercase tracking-[0.16em] text-slate-400">Timeline</div>
                          <div className="mt-3 space-y-3">
                            {selectedMemberUpdates.length === 0 ? (
                              <div className="text-sm text-muted-foreground">No timeline updates recorded yet.</div>
                            ) : selectedMemberUpdates.map((update) => (
                              <div key={update.id} className="rounded-xl border border-border/60 bg-white px-3 py-2 dark:border-slate-800 dark:bg-slate-950/80">
                                <div className="flex items-center justify-between gap-3 text-xs text-slate-500 dark:text-slate-400">
                                  <span>{update.author ? getDisplayName(update.author.full_name, update.author.email) : "System"}</span>
                                  <span>{formatDateTimeBD(update.created_at)}</span>
                                </div>
                                <div className="mt-1 text-sm font-medium text-slate-900 dark:text-slate-100">
                                  {update.update_type.replaceAll("_", " ")}
                                </div>
                                {update.message ? <div className="mt-1 text-sm text-muted-foreground">{update.message}</div> : null}
                              </div>
                            ))}
                          </div>
                        </div>
                      </>
                    ) : (
                      <div className="text-sm text-muted-foreground">No workload details are available yet.</div>
                    )}
                  </CardContent>
                </Card>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

function CreateTaskDialog({
  open,
  onOpenChange,
  form,
  setForm,
  members,
  canAssignTasks,
  currentUserId,
  isPending,
  onSubmit,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  form: NewTaskFormState;
  setForm: Dispatch<SetStateAction<NewTaskFormState>>;
  members: Array<{ id: string; label: string; email: string }>;
  canAssignTasks: boolean;
  currentUserId: string;
  isPending: boolean;
  onSubmit: () => void;
}) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogTrigger asChild>
        <Button className="rounded-full">
          <Plus className="mr-2 size-4" />
          Create task
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Create Internal Task</DialogTitle>
          <DialogDescription>Use lightweight internal tasks to track work that does not already live as a CRM object.</DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          <div>
            <label className="mb-1 block text-sm font-medium">Title</label>
            <Input value={form.title} onChange={(event) => setForm((current) => ({ ...current, title: event.target.value }))} placeholder="Prepare client follow-through checklist" />
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium">Description</label>
            <textarea
              className="min-h-[110px] w-full rounded-xl border border-input bg-background px-3 py-2 text-sm text-foreground outline-none transition focus:border-ring dark:border-slate-800 dark:bg-slate-950/85"
              value={form.description}
              onChange={(event) => setForm((current) => ({ ...current, description: event.target.value }))}
              placeholder="Share expectations, blockers, or required deliverables"
            />
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <label className="mb-1 block text-sm font-medium">Assignee</label>
              <select
                className="crm-filter-select"
                value={form.assignedTo}
                onChange={(event) => setForm((current) => ({ ...current, assignedTo: event.target.value }))}
                disabled={!canAssignTasks}
              >
                {!canAssignTasks ? <option value={currentUserId}>Myself</option> : null}
                {canAssignTasks ? <option value="">Select assignee</option> : null}
                {members.map((member) => (
                  <option key={member.id} value={member.id}>{member.label}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="mb-1 block text-sm font-medium">Priority</label>
              <select className="crm-filter-select" value={form.priority} onChange={(event) => setForm((current) => ({ ...current, priority: event.target.value as TeamTaskPriority }))}>
                {TEAM_TASK_PRIORITIES.map((priority) => (
                  <option key={priority} value={priority}>{priority}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="mb-1 block text-sm font-medium">Start date</label>
              <Input type="date" value={form.startDate} onChange={(event) => setForm((current) => ({ ...current, startDate: event.target.value }))} />
            </div>
            <div>
              <label className="mb-1 block text-sm font-medium">Due date</label>
              <Input type="date" value={form.dueDate} onChange={(event) => setForm((current) => ({ ...current, dueDate: event.target.value }))} />
            </div>
          </div>
        </div>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>Cancel</Button>
          <Button type="button" disabled={isPending || !form.title.trim()} onClick={onSubmit}>
            {isPending ? "Saving..." : "Create task"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function SummaryCard({
  title,
  value,
  helper,
  icon,
  tone,
}: {
  title: string;
  value: string;
  helper: string;
  icon: ReactNode;
  tone: "blue" | "orange" | "rose" | "slate" | "emerald";
}) {
  const tones = {
    blue: "bg-sky-100 text-sky-700 dark:bg-sky-500/10 dark:text-sky-300",
    orange: "bg-amber-100 text-amber-700 dark:bg-amber-500/10 dark:text-amber-300",
    rose: "bg-rose-100 text-rose-700 dark:bg-rose-500/10 dark:text-rose-300",
    slate: "bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300",
    emerald: "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-300",
  };

  return (
    <div className="rounded-[22px] border border-border/70 bg-white/95 p-4 shadow-sm dark:border-slate-800 dark:bg-slate-950/70">
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="text-sm font-medium text-slate-600 dark:text-slate-400">{title}</div>
          <div className="mt-3 text-3xl font-semibold tracking-tight text-slate-950 dark:text-slate-100">{value}</div>
        </div>
        <span className={`flex size-10 items-center justify-center rounded-2xl ${tones[tone]}`}>{icon}</span>
      </div>
      <div className="mt-4 text-xs text-slate-500 dark:text-slate-400">{helper}</div>
    </div>
  );
}

function DetailMetric({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-2xl border border-border/70 bg-white/90 px-3 py-3 dark:border-slate-800 dark:bg-slate-950/60">
      <div className="text-[11px] uppercase tracking-[0.14em] text-slate-400">{label}</div>
      <div className="mt-2 text-2xl font-semibold tracking-tight text-slate-950 dark:text-slate-100">{value}</div>
    </div>
  );
}
