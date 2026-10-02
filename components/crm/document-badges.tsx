import { Badge } from "@/components/ui/badge";
import { DocumentType, DocumentStatus } from "@/lib/crm/types";
import { cn } from "@/lib/utils";

export function DocumentTypeBadge({ type, className }: { type: DocumentType; className?: string }) {
  const variants: Record<DocumentType, string> = {
    "Company Profile": "bg-blue-100 text-blue-800 border-blue-200",
    "Brochure": "bg-indigo-100 text-indigo-800 border-indigo-200",
    "Quotation": "bg-amber-100 text-amber-800 border-amber-200",
    "Technical Proposal": "bg-purple-100 text-purple-800 border-purple-200",
    "Financial Proposal": "bg-emerald-100 text-emerald-800 border-emerald-200",
    "Agreement": "bg-rose-100 text-rose-800 border-rose-200",
    "Presentation": "bg-orange-100 text-orange-800 border-orange-200",
    "BOQ": "bg-cyan-100 text-cyan-800 border-cyan-200",
    "Meeting File": "bg-slate-100 text-slate-800 border-slate-200",
    "Product Catalogue": "bg-teal-100 text-teal-800 border-teal-200",
    "Invoice": "bg-green-100 text-green-800 border-green-200",
    "Purchase Order": "bg-sky-100 text-sky-800 border-sky-200",
    "Other": "bg-gray-100 text-gray-800 border-gray-200",
  };

  return (
    <Badge variant="outline" className={cn("font-medium", variants[type], className)}>
      {type}
    </Badge>
  );
}

export function DocumentStatusBadge({ status, className }: { status: DocumentStatus; className?: string }) {
  const variants: Record<DocumentStatus, string> = {
    draft: "bg-gray-100 text-gray-800 border-gray-200",
    submitted: "bg-blue-100 text-blue-800 border-blue-200",
    seen: "bg-indigo-100 text-indigo-800 border-indigo-200",
    revision_requested: "bg-amber-100 text-amber-800 border-amber-200",
    approved: "bg-green-100 text-green-800 border-green-200",
    rejected: "bg-red-100 text-red-800 border-red-200",
    archived: "bg-slate-100 text-slate-800 border-slate-200",
  };

  const labels: Record<DocumentStatus, string> = {
    draft: "Draft",
    submitted: "Submitted",
    seen: "Seen",
    revision_requested: "Revision Requested",
    approved: "Approved",
    rejected: "Rejected",
    archived: "Archived",
  };

  return (
    <Badge variant="outline" className={cn("font-medium", variants[status], className)}>
      {labels[status]}
    </Badge>
  );
}

export function FileSizeBadge({ sizeMb, className }: { sizeMb: number | null; className?: string }) {
  if (sizeMb === null) return null;
  
  return (
    <Badge variant="secondary" className={cn("font-mono text-[10px] px-1.5 py-0", className)}>
      {sizeMb < 1 ? `${(sizeMb * 1024).toFixed(0)} KB` : `${sizeMb.toFixed(2)} MB`}
    </Badge>
  );
}
