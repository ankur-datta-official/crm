"use client";

import { useState } from "react";
import { FileDown } from "lucide-react";
import { Button } from "@/components/ui/button";
import { getSignedDocumentDownloadUrl, logDocumentDownload } from "@/lib/crm/document-actions";

async function blobDownloadFromSignedUrl(url: string, fileName: string) {
  const response = await fetch(url);

  if (!response.ok) {
    throw new Error("Download failed. Please try again.");
  }

  const blob = await response.blob();
  const objectUrl = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = objectUrl;
  anchor.download = fileName || "document";
  anchor.style.display = "none";
  document.body.appendChild(anchor);
  anchor.click();
  document.body.removeChild(anchor);
  window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
}

export function useDocumentDownload() {
  const [downloadingDocumentId, setDownloadingDocumentId] = useState<string | null>(null);
  const [downloadError, setDownloadError] = useState<string | null>(null);

  async function downloadDocument(documentId: string) {
    setDownloadingDocumentId(documentId);
    setDownloadError(null);

    try {
      const { signedUrl, fileName } = await getSignedDocumentDownloadUrl(documentId);
      await blobDownloadFromSignedUrl(signedUrl, fileName);
      await logDocumentDownload(documentId);
    } catch (error) {
      setDownloadError(error instanceof Error ? error.message : "Download failed. Please try again.");
      throw error;
    } finally {
      setDownloadingDocumentId(null);
    }
  }

  return {
    downloadDocument,
    downloadingDocumentId,
    downloadError,
    clearDownloadError: () => setDownloadError(null),
  };
}

export function DocumentDownloadButton({
  documentId,
  fileName,
  variant = "outline",
  size,
  className,
}: {
  documentId: string;
  fileName: string;
  variant?: "default" | "outline" | "secondary" | "ghost" | "destructive";
  size?: "default" | "sm" | "lg" | "icon";
  className?: string;
}) {
  const { downloadDocument, downloadingDocumentId } = useDocumentDownload();
  const isDownloading = downloadingDocumentId === documentId;

  return (
    <Button
      variant={variant}
      size={size}
      className={className}
      disabled={isDownloading}
      onClick={() => void downloadDocument(documentId)}
    >
      <FileDown className="w-4 h-4 mr-2" />
      {isDownloading ? "Downloading..." : `Download ${fileName ? "" : "File"}`.trim()}
    </Button>
  );
}
