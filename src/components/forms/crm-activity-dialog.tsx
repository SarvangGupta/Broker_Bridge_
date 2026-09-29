"use client"

import { useState, useEffect } from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { toast } from "sonner"
import { Loader2, Plus } from "lucide-react"

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Badge } from "@/components/ui/badge"
import { Textarea } from "@/components/ui/textarea"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"

import { activitySchema } from "@/src/types/crm-schema"
import { logActivityAction, getCrmContactsAction } from "@/src/server/actions/crm-actions"

interface CrmActivityDialogProps {
  onLogged?: () => void;
  defaultContactId?: string;
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
  customTrigger?: React.ReactNode;
}

export function CrmActivityDialog({
  onLogged,
  defaultContactId,
  open: controlledOpen,
  onOpenChange: setControlledOpen,
  customTrigger,
}: CrmActivityDialogProps) {
  const [internalOpen, setInternalOpen] = useState(false);
  const [contacts, setContacts] = useState<any[]>([]);

  const isControlled = typeof controlledOpen === 'boolean';
  const open = isControlled ? controlledOpen : internalOpen;
  const setOpen = (val: boolean) => {
    if (isControlled && setControlledOpen) {
      setControlledOpen(val);
    } else {
      setInternalOpen(val);
    }
  };

  useEffect(() => {
    if (open && contacts.length === 0) {
      getCrmContactsAction().then((res) => {
        if (res.success && res.data) {
          setContacts(res.data);
        }
      });
    }
  }, [open, contacts.length]);

  const form = useForm<z.infer<typeof activitySchema>>({
    resolver: zodResolver(activitySchema),
    defaultValues: {
      contact_id: defaultContactId || '',
      type: 'Call',
      notes: '',
    },
  });

  useEffect(() => {
    if (defaultContactId && open) {
      form.setValue('contact_id', defaultContactId);
    }
  }, [defaultContactId, open, form]);

  async function onSubmit(values: z.infer<typeof activitySchema>) {
    try {
      const res = await logActivityAction(values);
      if (res.success) {
        toast.success('Activity logged successfully');
        setOpen(false);
        form.reset();
        if (onLogged) onLogged();
      } else {
        toast.error(res.error || 'Failed to log activity');
      }
    } catch (e) {
      toast.error('Unexpected error occurred');
    }
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      {customTrigger ? (
        <DialogTrigger render={customTrigger as any} />
      ) : (
        <DialogTrigger render={<Button variant="outline" className="min-h-[44px] rounded-xl border-slate-200 gap-2 font-semibold text-sm cursor-pointer" />}>
          <Plus className="h-4 w-4" />
          Log Activity
        </DialogTrigger>
      )}
      <DialogContent className="sm:max-w-[450px] p-6 bg-white">
        <DialogHeader className="text-left pb-2">
          <DialogTitle className="text-xl font-bold text-slate-900">Log CRM Activity</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4 pt-2">
            <FormField
              control={form.control}
              name="contact_id"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs font-semibold text-slate-700">Client / Contact</FormLabel>
                  <Select onValueChange={field.onChange} value={field.value || ""}>
                    <FormControl>
                      <SelectTrigger className="w-full min-h-[48px] rounded-xl border-slate-200 min-w-0 overflow-hidden">
                        <SelectValue placeholder="Select client / contact">
                          {field.value && contacts.find(c => c.id === field.value) ? (
                            <div className="flex items-center gap-1.5 truncate min-w-0">
                              <span className="font-semibold text-slate-900 truncate">{contacts.find(c => c.id === field.value)?.companyName}</span>
                              <span className="text-slate-500 text-xs truncate">— {contacts.find(c => c.id === field.value)?.userName}</span>
                            </div>
                          ) : undefined}
                        </SelectValue>
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent alignItemWithTrigger={false} className="w-[var(--radix-select-trigger-width)] max-h-[300px] overflow-y-auto">
                      {contacts.length === 0 ? (
                        <SelectItem value="none" disabled className="min-h-[48px] text-slate-400">
                          No contacts assigned yet
                        </SelectItem>
                      ) : (
                        contacts.map((c) => (
                          <SelectItem key={c.id} value={c.id} className="min-h-[48px] py-2.5 cursor-pointer max-w-full">
                            <div className="flex items-center justify-between w-full gap-2 overflow-hidden min-w-0">
                              <div className="truncate min-w-0">
                                <span className="font-medium text-slate-900">{c.companyName}</span>{" "}
                                <span className="text-muted-foreground text-xs">— {c.userName}</span>
                              </div>
                              <Badge variant="outline" className="text-[10px] shrink-0 font-medium px-2 py-0.5 bg-slate-50 text-slate-600 border-slate-200">
                                {c.role}
                              </Badge>
                            </div>
                          </SelectItem>
                        ))
                      )}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="type"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs font-semibold text-slate-700">Activity Type</FormLabel>
                  <Select onValueChange={field.onChange} value={field.value || ""}>
                    <FormControl>
                      <SelectTrigger className="min-h-[48px] rounded-xl border-slate-200">
                        <SelectValue placeholder="Select type" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {["Call", "Meeting", "Note", "Task"].map((t) => (
                        <SelectItem key={t} value={t} className="min-h-[44px]">
                          {t}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="notes"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs font-semibold text-slate-700">Notes</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="What was discussed?" 
                      className="min-h-[80px] rounded-xl border-slate-200 text-sm" 
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="follow_up_date"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-xs font-semibold text-slate-700">Follow-up Date (Optional)</FormLabel>
                  <FormControl>
                    <Input 
                      type="date" 
                      className="min-h-[48px] rounded-xl border-slate-200 text-sm"
                      value={field.value ? new Date(field.value).toISOString().split('T')[0] : ""}
                      onChange={(e) => field.onChange(e.target.value ? new Date(e.target.value) : undefined)}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <Button type="submit" className="w-full min-h-[48px] bg-[#0D9488] hover:bg-[#0F766E] text-white font-semibold rounded-xl text-sm shadow-sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              Log Activity
            </Button>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  )
}
