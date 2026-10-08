'use client';

import React, { useState, useTransition } from 'react';
import { 
  FileCheck2, 
  FileText, 
  ShieldCheck, 
  Truck, 
  Scale, 
  Receipt, 
  Leaf, 
  Loader2,
  CheckCircle2,
  AlertCircle
} from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { cn } from '@/lib/utils';
import { saveRequirementDocumentsAction } from '@/src/server/actions/buyer-document-actions';
import { STANDARD_DOCUMENT_TYPES } from '@/src/types/requirement-document-types';
import { toast } from 'sonner';

export interface DocumentTypeOption {
  id: string;
  name: string;
  shortCode: string;
  category: 'Quality' | 'Logistics' | 'Commercial' | 'Compliance';
  icon: React.ComponentType<{ className?: string }>;
  description: string;
  defaultSelected?: boolean;
}

export const PREDEFINED_REQUIREMENT_DOCUMENTS: DocumentTypeOption[] = [
  {
    id: 'coa',
    name: 'Certificate of Analysis',
    shortCode: 'COA',
    category: 'Quality',
    icon: ShieldCheck,
    description: 'Independent certified laboratory test report verifying quality parameters & chemical purity.',
    defaultSelected: true,
  },
  {
    id: 'lr',
    name: 'Lorry Receipt',
    shortCode: 'LR / Bilty',
    category: 'Logistics',
    icon: Truck,
    description: 'Transporter consignment note verifying vehicle loading, driver assignment, and dispatch.',
    defaultSelected: true,
  },
  {
    id: 'weighbridge',
    name: 'Weighbridge Slip',
    shortCode: 'Weight Slip',
    category: 'Logistics',
    icon: Scale,
    description: 'Certified electronic weight slips from origin gross/tare weighing and destination receipt.',
    defaultSelected: true,
  },
  {
    id: 'invoice',
    name: 'GST Invoice',
    shortCode: 'Tax Invoice',
    category: 'Commercial',
    icon: Receipt,
    description: 'Statutory GST commercial tax invoice issued by supplier confirming legal title transfer.',
    defaultSelected: true,
  },
  {
    id: 'phytosanitary',
    name: 'Phytosanitary Certificate',
    shortCode: 'Plant Health',
    category: 'Compliance',
    icon: Leaf,
    description: 'Government plant health & quarantine inspection certificate confirming pest-free cargo.',
    defaultSelected: false,
  },
];

export interface DocumentChecklistFormProps {
  requirementId?: string;
  value?: string[];
  onChange?: (documents: string[]) => void;
  disabled?: boolean;
  showSaveButton?: boolean;
  onSavedSuccess?: () => void;
}

export function DocumentChecklistForm({
  requirementId,
  value,
  onChange,
  disabled = false,
  showSaveButton = false,
  onSavedSuccess,
}: DocumentChecklistFormProps) {
  // If controlled (via value prop), use that; otherwise maintain internal state
  const isControlled = Array.isArray(value);

  const [internalDocs, setInternalDocs] = useState<string[]>(() => {
    if (isControlled) return value;
    // Default standard document requirements for bulk trade
    return PREDEFINED_REQUIREMENT_DOCUMENTS.filter((d) => d.defaultSelected).map((d) => d.name);
  });

  const selectedDocs = isControlled ? (value || []) : internalDocs;
  const [isPending, startTransition] = useTransition();

  const handleToggleDoc = (docName: string) => {
    if (disabled || isPending) return;

    const isAlreadySelected = selectedDocs.includes(docName);
    const updated = isAlreadySelected
      ? selectedDocs.filter((d) => d !== docName)
      : [...selectedDocs, docName];

    if (!isControlled) {
      setInternalDocs(updated);
    }
    onChange?.(updated);
  };

  const handleSave = async () => {
    if (!requirementId) {
      toast.error('Requirement ID is required to save document checklist.');
      return;
    }

    startTransition(async () => {
      try {
        const res = await saveRequirementDocumentsAction(requirementId, selectedDocs);
        if (res.success) {
          toast.success(`Saved ${selectedDocs.length} mandatory fulfillment documents.`);
          onSavedSuccess?.();
        } else {
          toast.error(res.error || 'Failed to save document checklist.');
        }
      } catch (err: any) {
        toast.error(err.message || 'Error saving document checklist.');
      }
    });
  };

  return (
    <Card className="border-slate-200 shadow-sm bg-white rounded-xl overflow-hidden w-full max-w-full">
      <CardHeader className="p-4 pb-3 border-b border-slate-100 bg-slate-50/50">
        <div className="flex items-center justify-between flex-wrap gap-2">
          <div className="flex items-center gap-2">
            <div className="p-2 rounded-lg bg-sky-50 text-[#0284C7] shrink-0">
              <FileCheck2 className="w-4 h-4" />
            </div>
            <div>
              <CardTitle className="text-sm font-bold text-slate-900 leading-tight">
                Mandatory Fulfillment Documents
              </CardTitle>
              <CardDescription className="text-xs text-slate-500 break-words mt-0.5">
                Select documents the seller must provide before dispatch approval & payment release.
              </CardDescription>
            </div>
          </div>

          <Badge
            variant="outline"
            className="text-[11px] font-semibold bg-sky-50 text-[#0284C7] border-sky-200 shrink-0"
          >
            {selectedDocs.length} of {PREDEFINED_REQUIREMENT_DOCUMENTS.length} Selected
          </Badge>
        </div>
      </CardHeader>

      <CardContent className="p-4 space-y-2.5">
        <div className="flex flex-col space-y-2">
          {PREDEFINED_REQUIREMENT_DOCUMENTS.map((doc) => {
            const isChecked = selectedDocs.includes(doc.name);
            const Icon = doc.icon;

            return (
              <label
                key={doc.id}
                htmlFor={`doc-check-${doc.id}`}
                className={cn(
                  "min-h-[48px] p-3 rounded-xl border transition-all flex items-start gap-3 cursor-pointer select-none max-w-full",
                  isChecked
                    ? "border-[#0284C7]/60 bg-sky-50/20 shadow-xs"
                    : "border-slate-200 bg-white hover:border-slate-300 hover:bg-slate-50/40"
                )}
              >
                {/* Checkbox Touch Target */}
                <div className="pt-0.5 shrink-0">
                  <Checkbox
                    id={`doc-check-${doc.id}`}
                    checked={isChecked}
                    disabled={disabled || isPending}
                    onCheckedChange={() => handleToggleDoc(doc.name)}
                    className="size-5 border-slate-300 data-checked:bg-[#0284C7] data-checked:border-[#0284C7]"
                  />
                </div>

                {/* Document Information & Badges */}
                <div className="flex flex-col space-y-1 min-w-0 flex-1">
                  <div className="flex items-center justify-between gap-2 flex-wrap">
                    <div className="flex items-center gap-1.5 min-w-0">
                      <Icon className={cn("w-3.5 h-3.5 shrink-0", isChecked ? "text-[#0284C7]" : "text-slate-400")} />
                      <span className="text-xs font-bold text-slate-900 break-words leading-tight">
                        {doc.name}
                      </span>
                    </div>

                    <div className="flex items-center gap-1.5 shrink-0">
                      <span className="text-[10px] font-mono font-medium px-1.5 py-0.2 rounded bg-slate-100 text-slate-600 border border-slate-200">
                        {doc.shortCode}
                      </span>
                      <span
                        className={cn(
                          "text-[10px] font-semibold px-1.5 py-0.2 rounded",
                          doc.category === 'Quality'
                            ? "bg-purple-50 text-purple-700 border border-purple-200"
                            : doc.category === 'Logistics'
                            ? "bg-blue-50 text-blue-700 border border-blue-200"
                            : doc.category === 'Commercial'
                            ? "bg-emerald-50 text-emerald-700 border border-emerald-200"
                            : "bg-amber-50 text-amber-700 border border-amber-200"
                        )}
                      >
                        {doc.category}
                      </span>
                    </div>
                  </div>

                  <p className="text-[11px] text-slate-500 leading-snug break-words">
                    {doc.description}
                  </p>
                </div>
              </label>
            );
          })}
        </div>

        {/* Informative Security Notice */}
        <div className="p-2.5 rounded-lg bg-slate-50 border border-slate-200 text-[11px] text-slate-500 flex items-start gap-2">
          <ShieldCheck className="w-4 h-4 text-[#0284C7] shrink-0 mt-0.5" />
          <p className="leading-snug break-words">
            Selected documents become hard contractual gates in the deal settlement and dispatch verification workflow.
          </p>
        </div>

        {/* Optional Standalone Save Button */}
        {showSaveButton && requirementId && (
          <div className="pt-2 flex justify-end">
            <Button
              type="button"
              onClick={handleSave}
              disabled={disabled || isPending}
              className="min-h-[48px] px-5 bg-[#0284C7] hover:bg-[#0369A1] text-white text-xs font-bold shadow-sm"
            >
              {isPending ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Saving Documents...
                </>
              ) : (
                <>
                  <CheckCircle2 className="w-4 h-4 mr-1.5" />
                  Save Document Requirements
                </>
              )}
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
