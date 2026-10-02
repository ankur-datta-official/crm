import Link from "next/link";
import { FileText, Download, MoreHorizontal, Eye, Edit, Archive } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger
} from "@/components/ui/dropdown-menu";
import { DocumentTypeBadge, DocumentStatusBadge } from "@/components/crm/document-badges";
import type { Document } from "@/lib/crm/types";
import { archiveDocument } from "@/lib/crm/document-actions";
import { useDocumentDownload } from "./document-download";

export function DocumentCard({ document }: { document: Document }) {
  const { downloadDocument, downloadingDocumentId } = useDocumentDownload();
  const isDownloading = downloadingDocumentId === document.id;

  return (
    <Card className="overflow-hidden border-l-4 border-l-primary">
      <CardContent className="p-4">
        <div className="flex items-start justify-between gap-4">
          <div className="space-y-2 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <Link 
                href={`/documents/${document.id}`}
                className="font-semibold hover:text-primary hover:underline transition-colors"
              >
                {document.title}
              </Link>
              <DocumentTypeBadge type={document.document_type} />
              <DocumentStatusBadge status={document.status} />
            </div>
            
            <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
              <div className="flex items-center gap-1.5">
                <FileText className="h-3.5 w-3.5" />
                <span>{document.file_name}</span>
              </div>
              {document.file_size_mb && (
                <span className="text-muted-foreground">
                  {document.file_size_mb} MB
                </span>
              )}
              <span className="uppercase font-medium">
                {document.file_extension}
              </span>
            </div>

            {document.uploaded_profile && (
              <div className="text-xs text-muted-foreground">
                Uploaded by: {document.uploaded_profile.full_name || document.uploaded_profile.email}
              </div>
            )}
          </div>

          <div className="flex items-center gap-1">
            <Button size="icon" variant="ghost" className="h-8 w-8" asChild>
              <Link href={`/documents/${document.id}`} title="View Details">
                <Eye className="h-4 w-4" />
              </Link>
            </Button>
            
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button size="icon" variant="ghost" className="h-8 w-8">
                  <MoreHorizontal className="h-4 w-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-40">
                <DropdownMenuItem asChild>
                  <Link href={`/documents/${document.id}`}>View Details</Link>
                </DropdownMenuItem>
                <DropdownMenuItem onClick={() => void downloadDocument(document.id)} disabled={isDownloading}>
                  <Download className="mr-2 h-4 w-4" />
                  {isDownloading ? "Downloading..." : "Download"}
                </DropdownMenuItem>
                <DropdownMenuItem asChild>
                  <Link href={`/documents/${document.id}/edit`}>Edit Metadata</Link>
                </DropdownMenuItem>
                {document.status !== "archived" && (
                  <form action={async () => {
                    "use server";
                    await archiveDocument(document.id);
                  }} className="w-full">
                    <DropdownMenuItem asChild>
                      <button className="flex w-full items-center text-amber-600">
                        <Archive className="mr-2 h-4 w-4" />
                        Archive
                      </button>
                    </DropdownMenuItem>
                  </form>
                )}
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
