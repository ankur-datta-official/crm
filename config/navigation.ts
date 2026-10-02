import type { LucideIcon } from "lucide-react";
import {
  BarChart3,
  Building2,
  CalendarClock,
  CircleHelp,
  FileText,
  Gift,
  Gauge,
  Handshake,
  KanbanSquare,
  Mail,
  ListChecks,
  Settings,
  ShieldCheck,
  Trophy,
  Users,
} from "lucide-react";

export const navSections = ["Overview", "Workspace", "Performance", "Admin"] as const;

export type SidebarSection = (typeof navSections)[number];

export type SidebarChildItem = {
  id: string;
  title: string;
  href: string;
  icon?: LucideIcon;
  tourKey?: string;
};

export type SidebarItem = {
  id: string;
  title: string;
  href?: string;
  icon: LucideIcon;
  section: SidebarSection;
  tourKey?: string;
  children?: SidebarChildItem[];
};

export const sidebarItems: SidebarItem[] = [
  { id: "dashboard", title: "Dashboard", href: "/dashboard", icon: Gauge, section: "Overview", tourKey: "tour-nav-dashboard" },
  {
    id: "team-management",
    title: "Team Management",
    icon: ShieldCheck,
    section: "Overview",
    tourKey: "tour-nav-team-management",
    children: [
      { id: "team-overview", title: "Team Overview", href: "/team?tab=members" },
      { id: "team-work", title: "Work Management", href: "/team?tab=work", icon: ListChecks },
      { id: "team-performance", title: "Team Performance", href: "/team?tab=performance", icon: BarChart3, tourKey: "tour-nav-team-dashboard" },
      { id: "team-invitations", title: "Invitations", href: "/team?tab=invitations", icon: Mail },
      { id: "team-roles", title: "Roles & Permissions", href: "/team?tab=roles", icon: ShieldCheck },
    ],
  },
  { id: "companies", title: "Companies / Leads", href: "/companies", icon: Building2, section: "Workspace", tourKey: "tour-nav-companies" },
  { id: "contacts", title: "Contacts", href: "/contacts", icon: Users, section: "Workspace", tourKey: "tour-nav-contacts" },
  { id: "meetings", title: "Meetings", href: "/meetings", icon: CalendarClock, section: "Workspace", tourKey: "tour-nav-meetings" },
  { id: "followups", title: "Follow-ups", href: "/followups", icon: Handshake, section: "Workspace", tourKey: "tour-nav-followups" },
  { id: "pipeline", title: "Pipeline", href: "/pipeline", icon: KanbanSquare, section: "Workspace", tourKey: "tour-nav-pipeline" },
  { id: "documents", title: "Documents", href: "/documents", icon: FileText, section: "Workspace", tourKey: "tour-nav-documents" },
  { id: "need-help", title: "Need Help", href: "/need-help", icon: CircleHelp, section: "Workspace" },
  { id: "leaderboard", title: "Leaderboard", href: "/leaderboard", icon: Trophy, section: "Performance" },
  { id: "rewards", title: "Rewards", href: "/rewards", icon: Gift, section: "Performance" },
  { id: "reports", title: "Reports", href: "/reports", icon: BarChart3, section: "Performance", tourKey: "tour-nav-reports" },
  { id: "my-work", title: "My Work", href: "/my-work", icon: ListChecks, section: "Performance" },
  { id: "settings", title: "Settings", href: "/settings", icon: Settings, section: "Admin" },
] satisfies SidebarItem[];
