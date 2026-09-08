"use client";

import React, { useState, useRef, useEffect, ChangeEvent, DragEvent, useTransition } from "react";
import {
  UploadCloud,
  FileText,
  Loader2,
  CheckCircle2,
  AlertCircle,
  ExternalLink,
  Trash2,
  FileCheck2,
  File,
  Image as ImageIcon,
  ShieldCheck,
  RefreshCw,
  Eye,
  Layers,
} from "lucide-react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { uploadFulfillmentDocument } from "@/src/lib/storage-utils";
import {
  attachDispatchDocumentAction,
  getDispatchDocumentsAction,
  deleteDispatchDocumentAction,
  type DispatchDocumentItem,
} from "@/src/server/actions/document-actions";
import {
  ALLOWED_DOCUMENT_TYPES,
  type DocumentTypeEnum,
} from "@/src/types/dispatch-schema";
import { format } from "date-fns";

export { ALLOWED_DOCUMENT_TYPES };

export interface FulfillmentDocumentUploadProps {
  dispatchId: string;
  bookingId: string;
  initialDocuments?: DispatchDocumentItem[];
  onUploadSuccess?: (doc: any) => void;
  className?: string;
  disabled?: boolean;
}

const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB
const ALLOWED_MIME_TYPES = ["application/pdf", "image/jpeg", "image/png"];
const ALLOWED_EXTENSIONS = [".pdf", ".jpg", ".jpeg", ".png"];

const DOCUMENT_TYPE_LABELS: Record<DocumentTypeEnum, string> = {
  LR: "Lorry Receipt (LR)",
  Invoice: "Official Tax Invoice",
  "E-Way Bill": "E-Way Bill",
  "Weighment Slip": "Weighment Slip",
  "Loading Photo": "Loading / Cargo Photo",
};

const DOCUMENT_TYPE_BADGES: Record<DocumentTypeEnum, { bg: string; text: string; border: string }> = {
  LR: { bg: "bg-blue-50", text: "text-blue-700", border: "border-blue-200" },
  Invoice: { bg: "bg-emerald-50", text: "text-[#047857]", border: "border-emerald-200" },
  "E-Way Bill": { bg: "bg-purple-50", text: "text-purple-700", border: "border-purple-200" },
  "Weighment Slip": { bg: "bg-amber-50", text: "text-amber-800", border: "border-amber-200" },
  "Loading Photo": { bg: "bg-teal-50", text: "text-teal-700", border: "border-teal-200" },
};

export function FulfillmentDocumentUpload({
  dispatchId,
  bookingId,
  initialDocuments,
  onUploadSuccess,
  className = "",
  disabled = false,
}: FulfillmentDocumentUploadProps) {
  const [selectedType, setSelectedType] = useState<DocumentTypeEnum>("LR");
  const [documents, setDocuments] = useState<DispatchDocumentItem[]>(initialDocuments || []);
  const [isLoadingDocs, setIsLoadingDocs] = useState<boolean>(!initialDocuments);
  const [isUploading, setIsUploading] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!initialDocuments && dispatchId) {
      loadDocuments();
    }
  }, [dispatchId, initialDocuments]);

  async function loadDocuments() {
    setIsLoadingDocs(true);
    try {
      const res = await getDispatchDocumentsAction(dispatchId);
      if (res.success && res.data) {
        setDocuments(res.data);
      }
    } catch (e: any) {
      console.error("Failed to load documents:", e);
    } finally {
      setIsLoadingDocs(false);
    }
  }

  const validateAndUpload = async (file: File) => {
    if (disabled || isUploading) return;

    // 1. Client-Side MIME & Extension Validation
    const isExtensionValid = ALLOWED_EXTENSIONS.some((ext) =>
      file.name.toLowerCase().endsWith(ext)
    );
    const isMimeValid = ALLOWED_MIME_TYPES.includes(file.type);

    if (!isMimeValid && !isExtensionValid) {
      toast.error("Invalid file format. Only PDF, JPG, and PNG documents are supported.");
      return;
    }

    // 2. Client-Side Size Validation (Max 5MB)
    if (file.size > MAX_FILE_SIZE_BYTES) {
      const sizeMb = (file.size / (1024 * 1024)).toFixed(1);
      toast.error(`File size exceeds 5MB limit (${sizeMb}MB). Please upload a smaller file.`);
      return;
    }

    setIsUploading(true);
    const toastId = toast.loading(`Uploading ${DOCUMENT_TYPE_LABELS[selectedType]}...`);

    try {
      // 3. Upload to private 'brokerbridge_documents' bucket via retry-safe utility
      const uploadedFilePath = await uploadFulfillmentDocument(file, bookingId, dispatchId);

      // 4. Attach to dispatch record via Server Action
      const attachRes = await attachDispatchDocumentAction({
        dispatchId,
        documentType: selectedType,
        fileUrl: uploadedFilePath,
      });

      if (attachRes.success) {
        toast.success(
          `${DOCUMENT_TYPE_LABELS[selectedType]} successfully uploaded and securely attached!`,
          { id: toastId }
        );
        onUploadSuccess?.(attachRes);
        await loadDocuments();
      } else {
        toast.error(attachRes.error || "Failed to attach document to dispatch.", { id: toastId });
      }
    } catch (err: any) {
      console.error("Upload error:", err);
      toast.error(err.message || "Failed to upload fulfillment document.", { id: toastId });
    } finally {
      setIsUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = "";
      }
    }
  };

  const handleFileChange = (e: ChangeEvent<HTMLInputElement>) => {
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

  const handleDelete = (docId: string) => {
    setDeletingId(docId);
    startTransition(async () => {
      try {
        const res = await deleteDispatchDocumentAction(docId);
        if (res.success) {
          toast.success("Document removed.");
          setDocuments((prev) => prev.filter((d) => d.id !== docId));
        } else {
          toast.error(res.error || "Failed to remove document.");
        }
      } catch (err: any) {
        toast.error(err.message || "An error occurred while deleting document.");
      } finally {
        setDeletingId(null);
      }
    });
  };

  return (
    <div className={cn("space-y-6", className)}>
      {/* 1. DOCUMENT TYPE SELECTOR & DROPZONE */}
      <div className="p-5 sm:p-6 rounded-2xl bg-slate-50/80 border border-slate-200/90 space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-slate-200/70">
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-lg bg-emerald-100 flex items-center justify-center text-[#047857]">
              <FileCheck2 className="w-4 h-4" />
            </div>
            <div>
              <h4 className="text-sm font-bold text-slate-900">
                Fulfillment Documents Vault
              </h4>
              <p className="text-xs text-slate-500">
                Upload LRs, Tax Invoices, E-Way bills, and Weight Slips for this shipment.
              </p>
            </div>
          </div>

          <div className="flex items-center gap-1.5">
            <Badge
              variant="outline"
              className="bg-white text-slate-700 border-slate-300 text-xs font-semibold px-2.5 py-1 gap-1"
            >
              <ShieldCheck className="w-3.5 h-3.5 text-[#047857]" />
              <span>15-Min Signed URLs</span>
            </Badge>
          </div>
        </div>

        {/* CONTROLS ROW */}
        <div className="grid grid-cols-1 sm:grid-cols-12 gap-4 items-center">
          <div className="sm:col-span-5 space-y-1">
            <label className="text-xs font-bold text-slate-700">
              Select Document Category *
            </label>
            <Select
              value={selectedType}
              onValueChange={(val) => setSelectedType(val as DocumentTypeEnum)}
              disabled={disabled || isUploading}
            >
              <SelectTrigger className="h-12 bg-white rounded-xl border-slate-200 focus:ring-emerald-500 font-medium text-slate-900">
                <SelectValue placeholder="Select Document Type" />
              </SelectTrigger>
              <SelectContent>
                {ALLOWED_DOCUMENT_TYPES.map((type) => (
                  <SelectItem key={type} value={type} className="cursor-pointer font-medium">
                    {DOCUMENT_TYPE_LABELS[type]}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="sm:col-span-7 flex items-end">
            <div className="w-full text-xs text-slate-500 sm:text-right pt-1">
              Accepted: <span className="font-semibold text-slate-700">PDF, JPG, PNG</span> (Max 5MB)
            </div>
          </div>
        </div>

        {/* DROPZONE AREA */}
        <div
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          onDrop={handleDrop}
          onClick={() => {
            if (!disabled && !isUploading) {
              fileInputRef.current?.click();
            }
          }}
          className={cn(
            "border-2 border-dashed rounded-2xl p-6 text-center cursor-pointer transition-all duration-200 bg-white",
            isDragging
              ? "border-emerald-500 bg-emerald-50/50 scale-[1.005]"
              : "border-slate-200 hover:border-emerald-400 hover:bg-slate-50/50",
            (disabled || isUploading) && "opacity-60 cursor-not-allowed"
          )}
        >
          <input
            ref={fileInputRef}
            type="file"
            accept=".pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png"
            onChange={handleFileChange}
            className="hidden"
            disabled={disabled || isUploading}
          />

          <div className="flex flex-col items-center justify-center space-y-3">
            <div
              className={cn(
                "w-12 h-12 rounded-2xl flex items-center justify-center transition-colors",
                isDragging
                  ? "bg-emerald-100 text-emerald-700"
                  : "bg-slate-100 text-slate-500"
              )}
            >
              {isUploading ? (
                <Loader2 className="w-6 h-6 animate-spin text-[#047857]" />
              ) : (
                <UploadCloud className="w-6 h-6" />
              )}
            </div>

            <div className="space-y-1">
              <div className="text-sm font-bold text-slate-900">
                {isUploading ? (
                  <span>Encrypting & Uploading Document...</span>
                ) : (
                  <span>
                    Click to browse or drag & drop{" "}
                    <span className="text-[#047857] underline underline-offset-2">
                      {DOCUMENT_TYPE_LABELS[selectedType]}
                    </span>
                  </span>
                )}
              </div>
              <p className="text-xs text-slate-400">
                Strict request-time authorization • Direct bucket transfer
              </p>
            </div>

            <Button
              type="button"
              disabled={disabled || isUploading}
              variant="outline"
              className="h-12 min-h-[48px] px-6 rounded-xl font-bold text-xs border-emerald-300 text-[#047857] hover:bg-emerald-50 gap-2 cursor-pointer mt-1"
            >
              {isUploading ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Processing Upload...</span>
                </>
              ) : (
                <>
                  <UploadCloud className="w-4 h-4" />
                  <span>Select File (Max 5MB)</span>
                </>
              )}
            </Button>
          </div>
        </div>
      </div>

      {/* 2. ATTACHED DOCUMENTS LEDGER */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Layers className="w-4 h-4 text-slate-600" />
            <h5 className="text-xs font-bold uppercase tracking-wider text-slate-700">
              Attached Shipment Documents ({documents.length})
            </h5>
          </div>

          <Button
            type="button"
            onClick={loadDocuments}
            variant="ghost"
            size="sm"
            disabled={isLoadingDocs}
            className="h-8 text-xs text-slate-500 hover:text-slate-900 gap-1 rounded-lg"
          >
            <RefreshCw className={cn("w-3 h-3", isLoadingDocs && "animate-spin")} />
            <span>Refresh</span>
          </Button>
        </div>

        {isLoadingDocs ? (
          <div className="p-6 rounded-2xl bg-white border border-slate-200 text-center text-xs text-slate-400 flex items-center justify-center gap-2">
            <Loader2 className="w-4 h-4 animate-spin text-slate-400" />
            <span>Fetching document vault...</span>
          </div>
        ) : documents.length === 0 ? (
          <div className="p-6 rounded-2xl bg-white border border-slate-200 text-center space-y-1">
            <FileText className="w-6 h-6 text-slate-300 mx-auto" />
            <p className="text-xs font-semibold text-slate-600">
              No fulfillment documents attached yet.
            </p>
            <p className="text-[11px] text-slate-400">
              Upload the Lorry Receipt (LR) or Tax Invoice to enable downstream settlement and verification.
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-2.5">
            {documents.map((doc) => {
              const typeConfig =
                DOCUMENT_TYPE_BADGES[doc.documentType as DocumentTypeEnum] || {
                  bg: "bg-slate-50",
                  text: "text-slate-700",
                  border: "border-slate-200",
                };

              const isPdf = doc.fileName.toLowerCase().endsWith(".pdf");
              const isDeleting = deletingId === doc.id;

              return (
                <div
                  key={doc.id}
                  className="p-3.5 bg-white rounded-2xl border border-slate-200/90 shadow-2xs flex flex-col sm:flex-row sm:items-center justify-between gap-3 hover:border-slate-300 transition-colors"
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <div className="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center text-slate-600 shrink-0">
                      {isPdf ? (
                        <FileText className="w-4 h-4 text-rose-600" />
                      ) : (
                        <ImageIcon className="w-4 h-4 text-blue-600" />
                      )}
                    </div>

                    <div className="min-w-0 space-y-0.5">
                      <div className="flex items-center gap-2 flex-wrap">
                        <Badge
                          variant="outline"
                          className={cn(
                            "text-[10px] font-bold px-2 py-0.5",
                            typeConfig.bg,
                            typeConfig.text,
                            typeConfig.border
                          )}
                        >
                          {doc.documentType}
                        </Badge>
                        <span className="text-xs font-bold text-slate-900 truncate max-w-[220px] sm:max-w-[320px]">
                          {doc.fileName}
                        </span>
                      </div>
                      <div className="text-[11px] text-slate-400">
                        Uploaded {format(new Date(doc.createdAt), "dd MMM yyyy, hh:mm a")}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 shrink-0 self-end sm:self-center">
                    {doc.signedUrl ? (
                      <a
                        href={doc.signedUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex"
                      >
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          className="h-10 min-h-[40px] px-3.5 rounded-xl font-bold text-xs text-slate-700 hover:bg-slate-50 gap-1.5 cursor-pointer border-slate-200"
                        >
                          <Eye className="w-3.5 h-3.5 text-slate-500" />
                          <span>View Document</span>
                          <ExternalLink className="w-3 h-3 text-slate-400" />
                        </Button>
                      </a>
                    ) : (
                      <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        disabled
                        className="h-10 text-xs text-slate-400 gap-1"
                      >
                        <span>Access Expired</span>
                      </Button>
                    )}

                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      onClick={() => handleDelete(doc.id)}
                      disabled={isDeleting || disabled}
                      className="h-10 w-10 p-0 rounded-xl text-slate-400 hover:text-rose-600 hover:bg-rose-50 cursor-pointer"
                      title="Delete Document"
                    >
                      {isDeleting ? (
                        <Loader2 className="w-4 h-4 animate-spin text-rose-600" />
                      ) : (
                        <Trash2 className="w-4 h-4" />
                      )}
                    </Button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
