"use client";

import { useState, useRef, ChangeEvent, DragEvent } from "react";
import {
  UploadCloud,
  FileText,
  Loader2,
  CheckCircle2,
  AlertCircle,
  ExternalLink,
  RefreshCw,
  FileCheck,
} from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { uploadLabEvidence } from "@/src/lib/storage-utils";
import {
  attachLabDocumentAction,
  getLabEvidenceSignedUrlAction,
} from "@/src/server/actions/lab-actions";

interface LabDocumentUploadProps {
  availabilityId: string;
  labTestId?: string;
  existingFileUrl?: string | null;
  onUploadComplete?: (fileUrl: string) => void;
  onFileSelect?: (file: File) => void | Promise<void>;
  disabled?: boolean;
}

const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB
const ALLOWED_MIME_TYPES = ["application/pdf", "image/jpeg", "image/png"];
const ALLOWED_EXTENSIONS = [".pdf", ".jpg", ".jpeg", ".png"];

export function LabDocumentUpload({
  availabilityId,
  labTestId,
  existingFileUrl,
  onUploadComplete,
  onFileSelect,
  disabled = false,
}: LabDocumentUploadProps) {
  const [fileUrl, setFileUrl] = useState<string | null>(existingFileUrl || null);
  const [isUploading, setIsUploading] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [isViewing, setIsViewing] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const validateAndUpload = async (file: File) => {
    // 1. Client-Side Validation: File Type
    const isValidType =
      ALLOWED_MIME_TYPES.includes(file.type) ||
      ALLOWED_EXTENSIONS.some((ext) => file.name.toLowerCase().endsWith(ext));

    if (!isValidType) {
      toast.error("Invalid file type. Only PDF, JPG, and PNG files are accepted.");
      return;
    }

    // 2. Client-Side Validation: File Size (5MB)
    if (file.size > MAX_FILE_SIZE_BYTES) {
      const sizeMb = (file.size / (1024 * 1024)).toFixed(1);
      toast.error(`File is too large (${sizeMb}MB). Maximum allowed size is 5MB.`);
      return;
    }

    // Immediately trigger OCR extraction before / in parallel with storage upload
    if (onFileSelect) {
      try {
        onFileSelect(file);
      } catch (err) {
        console.error("onFileSelect error:", err);
      }
    }

    setIsUploading(true);
    try {
      // 3. Upload to private Supabase storage bucket
      const uploadedPath = await uploadLabEvidence(file, availabilityId);

      // 4. Attach document path to the lot's lab_tests record
      const attachRes = await attachLabDocumentAction({
        availabilityId,
        fileUrl: uploadedPath,
      });

      if (attachRes.success) {
        setFileUrl(uploadedPath);
        toast.success("Laboratory evidence document attached successfully!");
        onUploadComplete?.(uploadedPath);
      } else {
        toast.error(attachRes.error || "Failed to link uploaded document.");
      }
    } catch (err: any) {
      console.error("Upload error:", err);
      toast.error(err.message || "Failed to upload laboratory evidence.");
    } finally {
      setIsUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = "";
      }
    }
  };

  const handleFileSelect = (e: ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (files && files.length > 0) {
      validateAndUpload(files[0]);
    }
  };

  const handleDragOver = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    if (!disabled && !isUploading) {
      setIsDragging(true);
    }
  };

  const handleDragLeave = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragging(false);
  };

  const handleDrop = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragging(false);
    if (disabled || isUploading) return;

    const files = e.dataTransfer.files;
    if (files && files.length > 0) {
      validateAndUpload(files[0]);
    }
  };

  const handleViewDocument = async () => {
    if (!fileUrl) return;
    setIsViewing(true);
    try {
      const res = await getLabEvidenceSignedUrlAction(fileUrl);
      if (res.success && res.data?.signedUrl) {
        window.open(res.data.signedUrl, "_blank", "noopener,noreferrer");
      } else {
        toast.error(res.error || "Unable to open document.");
      }
    } catch (err: any) {
      toast.error("Failed to generate secure document link.");
    } finally {
      setIsViewing(false);
    }
  };

  const getCleanFileName = (path: string) => {
    const parts = path.split("/");
    const full = parts[parts.length - 1];
    // Strip timestamp prefix if present
    const idx = full.indexOf("_");
    return idx > 0 ? full.substring(idx + 1) : full;
  };

  return (
    <div className="space-y-3">
      {/* Existing File Card if attached */}
      {fileUrl && (
        <div className="flex flex-col sm:flex-row sm:items-center justify-between p-3.5 rounded-xl border border-emerald-200 bg-emerald-50/50 gap-3">
          <div className="flex items-center space-x-3 overflow-hidden">
            <div className="p-2 rounded-lg bg-emerald-100 text-emerald-800 shrink-0">
              <FileCheck className="h-5 w-5" />
            </div>
            <div className="overflow-hidden">
              <p className="text-sm font-bold text-slate-900 truncate">
                {getCleanFileName(fileUrl)}
              </p>
              <p className="text-xs text-slate-500 mt-0.5">Attached to Lot</p>
            </div>
          </div>

          <div className="flex items-center space-x-2 shrink-0">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={handleViewDocument}
              disabled={isViewing}
              className="min-h-[48px] h-12 bg-white px-4 text-xs font-semibold rounded-xl"
            >
              {isViewing ? (
                <Loader2 className="h-4 w-4 animate-spin mr-1.5" />
              ) : (
                <ExternalLink className="h-4 w-4 mr-1.5 text-slate-600" />
              )}
              View Report
            </Button>
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={() => fileInputRef.current?.click()}
              disabled={disabled || isUploading}
              className="min-h-[48px] h-12 px-3 text-xs text-slate-600 hover:text-slate-900 rounded-xl"
            >
              <RefreshCw className="h-4 w-4 mr-1" />
              Replace
            </Button>
          </div>
        </div>
      )}

      {/* Drag & Drop Upload Zone */}
      <div
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onClick={() => !isUploading && !disabled && fileInputRef.current?.click()}
        className={cn(
          "flex flex-col items-center justify-center p-6 border-2 border-dashed rounded-xl cursor-pointer transition-all duration-200 text-center min-h-[140px]",
          isDragging
            ? "border-emerald-600 bg-emerald-50/50 scale-[0.99]"
            : "border-slate-300 hover:border-slate-400 bg-slate-50/60 hover:bg-slate-50",
          (disabled || isUploading) && "pointer-events-none opacity-60",
          fileUrl ? "py-4" : "py-6"
        )}
      >
        <input
          ref={fileInputRef}
          type="file"
          accept=".pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png"
          onChange={handleFileSelect}
          className="hidden"
          disabled={disabled || isUploading}
        />

        {isUploading ? (
          <div className="flex flex-col items-center space-y-2">
            <Loader2 className="h-7 w-7 animate-spin text-emerald-600" />
            <p className="text-sm font-bold text-slate-800">
              Reading report...
            </p>
            <p className="text-xs text-slate-500">Please wait a moment</p>
          </div>
        ) : (
          <div className="flex flex-col items-center space-y-2">
            <div className="p-3 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-100">
              <UploadCloud className="h-6 w-6 text-emerald-600" />
            </div>
            <div>
              <p className="text-base font-bold text-slate-900">
                Upload Lab Report
              </p>
              <p className="text-xs text-slate-500 mt-0.5 font-medium">
                PDF, JPG or PNG (up to 5MB)
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
