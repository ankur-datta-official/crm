"use client";

import { useState, useRef } from "react";
import { Upload, X, FileIcon, CheckCircle2, AlertCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";

type FileUploadFieldProps = {
  label?: string;
  required?: boolean;
  error?: string;
  accept?: string;
  maxSizeMb?: number;
  onFileSelect: (file: File | null) => void;
  currentFileName?: string;
};

export function FileUploadField({
  label = "Upload File",
  required,
  error,
  accept = ".pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.png,.jpg,.jpeg,.webp,.zip",
  maxSizeMb = 10,
  onFileSelect,
  currentFileName,
}: FileUploadFieldProps) {
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [fileError, setFileError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    setFileError(null);

    if (!file) {
      setSelectedFile(null);
      onFileSelect(null);
      return;
    }

    const fileSizeMb = file.size / (1024 * 1024);
    if (fileSizeMb > maxSizeMb) {
      const errorMsg = `File size exceeds ${maxSizeMb}MB limit. Current: ${fileSizeMb.toFixed(2)}MB`;
      setFileError(errorMsg);
      setSelectedFile(null);
      onFileSelect(null);
      if (inputRef.current) inputRef.current.value = "";
      return;
    }

    setSelectedFile(file);
    onFileSelect(file);
  };

  const clearFile = () => {
    setSelectedFile(null);
    setFileError(null);
    onFileSelect(null);
    if (inputRef.current) inputRef.current.value = "";
  };

  return (
    <div className="space-y-2">
      <Label className="flex items-center justify-between">
        <span>
          {label}
          {required ? <span className="text-destructive"> *</span> : null}
        </span>
        <span className="text-[10px] text-muted-foreground font-normal">
          Max {maxSizeMb}MB
        </span>
      </Label>

      <div
        className={cn(
          "relative group border-2 border-dashed rounded-lg transition-colors p-4 flex flex-col items-center justify-center min-h-32 text-center",
          selectedFile || currentFileName
            ? "border-primary/50 bg-primary/5"
            : "border-muted-foreground/20 hover:border-primary/50 hover:bg-muted/50",
          (error || fileError) && "border-destructive bg-destructive/5"
        )}
      >
        <input
          ref={inputRef}
          type="file"
          accept={accept}
          onChange={handleFileChange}
          className="absolute inset-0 w-full h-full opacity-0 cursor-pointer disabled:cursor-not-allowed"
          title=""
        />

        {selectedFile ? (
          <div className="flex flex-col items-center gap-2">
            <div className="p-2 bg-primary/10 rounded-full text-primary">
              <CheckCircle2 className="w-6 h-6" />
            </div>
            <div className="space-y-1">
              <p className="text-sm font-medium truncate max-w-[200px]">
                {selectedFile.name}
              </p>
              <p className="text-xs text-muted-foreground">
                {(selectedFile.size / (1024 * 1024)).toFixed(2)} MB
              </p>
            </div>
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="mt-2 text-destructive hover:text-destructive hover:bg-destructive/10 z-10"
              onClick={(e) => {
                e.stopPropagation();
                clearFile();
              }}
            >
              <X className="w-4 h-4 mr-1" />
              Remove
            </Button>
          </div>
        ) : currentFileName ? (
          <div className="flex flex-col items-center gap-2">
            <div className="p-2 bg-muted rounded-full text-muted-foreground">
              <FileIcon className="w-6 h-6" />
            </div>
            <div className="space-y-1">
              <p className="text-sm font-medium truncate max-w-[200px]">
                {currentFileName}
              </p>
              <p className="text-xs text-muted-foreground italic">
                Existing file (Click to replace)
              </p>
            </div>
          </div>
        ) : (
          <div className="flex flex-col items-center gap-2">
            <div className="p-2 bg-muted rounded-full text-muted-foreground group-hover:bg-primary/10 group-hover:text-primary transition-colors">
              <Upload className="w-6 h-6" />
            </div>
            <div className="space-y-1">
              <p className="text-sm font-medium">Click or drag to upload</p>
              <p className="text-xs text-muted-foreground">
                PDF, DOCX, XLSX, Images, ZIP
              </p>
            </div>
          </div>
        )}
      </div>

      {(error || fileError) && (
        <p className="text-xs text-destructive flex items-center gap-1">
          <AlertCircle className="w-3 h-3" />
          {error || fileError}
        </p>
      )}
    </div>
  );
}
