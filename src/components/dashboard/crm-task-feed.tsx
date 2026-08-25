"use client"

import { useState, useEffect } from "react"
import { toast } from "sonner"
import { format, isToday, isPast } from "date-fns"
import { Loader2, Plus, CalendarIcon, CheckSquare, Clock, AlertCircle, Building2 } from "lucide-react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"

import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
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
import { Textarea } from "@/components/ui/textarea"
import { Input } from "@/components/ui/input"

import { taskSchema } from "@/src/types/crm-schema"
import { getTasksAction, createTaskAction, toggleTaskStatusAction, getCrmContactsAction } from "@/src/server/actions/crm-actions"
import { CrmActivityDialog } from "@/src/components/forms/crm-activity-dialog"

const TIME_OPTIONS = [
  "06:00 AM", "06:30 AM", "07:00 AM", "07:30 AM", "08:00 AM", "08:30 AM",
  "09:00 AM", "09:30 AM", "10:00 AM", "10:30 AM", "11:00 AM", "11:30 AM",
  "12:00 PM", "12:30 PM", "01:00 PM", "01:30 PM", "02:00 PM", "02:30 PM",
  "03:00 PM", "03:30 PM", "04:00 PM", "04:30 PM", "05:00 PM", "05:30 PM",
  "06:00 PM", "06:30 PM", "07:00 PM", "07:30 PM", "08:00 PM", "08:30 PM",
  "09:00 PM", "09:30 PM", "10:00 PM", "10:30 PM", "11:00 PM", "11:30 PM"
]

export function CrmTaskFeed() {
  const [tasks, setTasks] = useState<any[]>([])
  const [contacts, setContacts] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [taskDialogOpen, setTaskDialogOpen] = useState(false)
  const [togglingId, setTogglingId] = useState<string | null>(null)

  const [selectedDate, setSelectedDate] = useState<string>("")
  const [selectedTime, setSelectedTime] = useState<string>("10:00 AM")

  const form = useForm<z.infer<typeof taskSchema>>({
    resolver: zodResolver(taskSchema),
    defaultValues: {
      contact_id: "",
      title: "",
      priority: "Medium",
    }
  })

  useEffect(() => {
    fetchData()
  }, [])

  useEffect(() => {
    if (taskDialogOpen) {
      getCrmContactsAction().then(res => {
        if (res.success && res.data) {
          setContacts(res.data)
        }
      })
    }
  }, [taskDialogOpen])

  async function fetchData() {
    setLoading(true)
    try {
      const [tasksRes, contactsRes] = await Promise.all([
        getTasksAction(),
        getCrmContactsAction()
      ])
      if (tasksRes.success) setTasks(tasksRes.data || [])
      if (contactsRes.success) setContacts(contactsRes.data || [])
    } catch (e: any) {
      console.error(e)
      toast.error(e.message || "Failed to load CRM data")
    } finally {
      setLoading(false)
    }
  }

  async function onSubmit(values: z.infer<typeof taskSchema>) {
    try {
      if (!selectedDate) {
        toast.error("Please select a due date")
        return
      }

      // Combine Date + Time into a single timestamp
      const [time, modifier] = selectedTime.split(" ")
      let [hours, minutes] = time.split(":").map(Number)
      if (modifier === "PM" && hours < 12) hours += 12
      if (modifier === "AM" && hours === 12) hours = 0

      const finalDate = new Date(selectedDate)
      finalDate.setHours(hours, minutes, 0, 0)

      const payload = {
        ...values,
        due_date: finalDate,
      }

      const res = await createTaskAction(payload)
      if (res.success) {
        toast.success("Task reminder created successfully")
        setTaskDialogOpen(false)
        form.reset()
        setSelectedDate("")
        setSelectedTime("10:00 AM")
        fetchData()
      } else {
        toast.error(res.error || "Failed to create task")
      }
    } catch (e) {
      toast.error("Unexpected error occurred")
    }
  }

  async function handleToggle(id: string) {
    setTogglingId(id)
    try {
      const res = await toggleTaskStatusAction(id)
      if (res.success) {
        toast.success("Task status updated")
        fetchData()
      } else {
        toast.error(res.error || "Failed to update status")
      }
    } catch (e) {
      toast.error("Unexpected error")
    } finally {
      setTogglingId(null)
    }
  }

  const getPriorityBadge = (p: string) => {
    if (p === 'High') {
      return (
        <Badge variant="outline" className="bg-rose-50 text-rose-700 border-rose-200 font-semibold px-2.5 py-0.5 text-xs rounded-full">
          High Priority
        </Badge>
      )
    }
    if (p === 'Medium') {
      return (
        <Badge variant="outline" className="bg-amber-50 text-amber-700 border-amber-200 font-semibold px-2.5 py-0.5 text-xs rounded-full">
          Medium Priority
        </Badge>
      )
    }
    return (
      <Badge variant="outline" className="bg-slate-50 text-slate-600 border-slate-200 font-semibold px-2.5 py-0.5 text-xs rounded-full">
        Low Priority
      </Badge>
    )
  }

  const getContactDisplay = (contactId: string) => {
    const c = contacts.find((contact) => contact.id === contactId)
    if (!c) return { company: "Direct Client", name: "Follow-up", role: "Trader" }
    return {
      company: c.companyName || "Independent",
      name: c.userName || "Client Contact",
      role: c.role || "Client"
    }
  }

  // Sort tasks: Overdue and Today's tasks first, then by earliest due date
  const sortedTasks = [...tasks].sort((a, b) => {
    const dateA = new Date(a.dueDate).getTime()
    const dateB = new Date(b.dueDate).getTime()
    const now = Date.now()
    
    const isOverdueA = dateA < now
    const isOverdueB = dateB < now

    if (isOverdueA && !isOverdueB) return -1
    if (!isOverdueA && isOverdueB) return 1
    return dateA - dateB
  })

  return (
    <Card className="w-full bg-white rounded-2xl border border-slate-200/80 shadow-sm overflow-hidden">
      <CardHeader className="p-5 sm:p-6 border-b border-slate-100 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <CardTitle className="text-xl font-bold text-slate-900">CRM & Tasks</CardTitle>
          <CardDescription className="text-sm text-slate-500 mt-0.5">
            Manage your scheduled calls, client reminders, and follow-ups.
          </CardDescription>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <CrmActivityDialog onLogged={fetchData} />
          
          <Dialog open={taskDialogOpen} onOpenChange={setTaskDialogOpen}>
            <DialogTrigger render={<Button className="bg-[#0D9488] hover:bg-[#0F766E] text-white font-semibold shadow-sm hover:shadow transition-all rounded-xl px-4 min-h-[44px] gap-2 text-sm cursor-pointer" />}>
              <Plus className="h-4 w-4 stroke-[2.5]" />
              Add Task Reminder
            </DialogTrigger>
            <DialogContent className="sm:max-w-[480px] p-6 bg-white">
              <DialogHeader className="text-left pb-2">
                <DialogTitle className="text-xl font-bold text-slate-900">Add New Task Reminder</DialogTitle>
                <DialogDescription className="text-xs text-slate-500">
                  Set a reminder for calls, rate negotiations, or document checks.
                </DialogDescription>
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
                              contacts.map((contact) => (
                                <SelectItem key={contact.id} value={contact.id} className="min-h-[48px] py-2.5 cursor-pointer max-w-full">
                                  <div className="flex items-center justify-between w-full gap-2 overflow-hidden min-w-0">
                                    <div className="truncate min-w-0">
                                      <span className="font-medium text-slate-900">{contact.companyName}</span>{" "}
                                      <span className="text-muted-foreground text-xs">— {contact.userName}</span>
                                    </div>
                                    <Badge variant="outline" className="text-[10px] shrink-0 font-medium px-2 py-0.5 bg-slate-50 text-slate-600 border-slate-200">
                                      {contact.role}
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
                  
                  {/* Task Description / Title - Voice-to-Text / Hinglish Optimized */}
                  <FormField
                    control={form.control}
                    name="title"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-xs font-semibold text-slate-700">
                          Task Description / Notes
                        </FormLabel>
                        <FormControl>
                          <Textarea 
                            placeholder='e.g., "Kal subah rate negotiate karna hai..." or "Call buyer to confirm payment dispatch"' 
                            className="min-h-[90px] rounded-xl border-slate-200 resize-y text-sm" 
                            {...field} 
                          />
                        </FormControl>
                        <p className="text-[11px] text-slate-400">
                          Tip: Use your phone keyboard microphone for voice-typing in Hindi or English.
                        </p>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  {/* Due Date & Time Pickers */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div className="space-y-2">
                      <FormLabel className="text-xs font-semibold text-slate-700">Due Date</FormLabel>
                      <Input 
                        type="date" 
                        className="min-h-[48px] rounded-xl border-slate-200 text-sm"
                        value={selectedDate}
                        onChange={(e) => setSelectedDate(e.target.value)}
                      />
                    </div>

                    <div className="space-y-2">
                      <FormLabel className="text-xs font-semibold text-slate-700">Reminder Time</FormLabel>
                      <Select value={selectedTime} onValueChange={(val) => val && setSelectedTime(val)}>
                        <SelectTrigger className="min-h-[48px] rounded-xl border-slate-200 text-sm">
                          <SelectValue placeholder="Select time" />
                        </SelectTrigger>
                        <SelectContent className="max-h-[220px]">
                          {TIME_OPTIONS.map((time) => (
                            <SelectItem key={time} value={time} className="min-h-[40px]">
                              {time}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  </div>

                  <FormField
                    control={form.control}
                    name="priority"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-xs font-semibold text-slate-700">Priority Level</FormLabel>
                        <Select onValueChange={field.onChange} value={field.value || ""}>
                          <FormControl>
                            <SelectTrigger className="min-h-[48px] rounded-xl border-slate-200">
                              <SelectValue placeholder="Select priority" />
                            </SelectTrigger>
                          </FormControl>
                          <SelectContent>
                            <SelectItem value="High" className="min-h-[44px]">High Priority (Urgent)</SelectItem>
                            <SelectItem value="Medium" className="min-h-[44px]">Medium Priority</SelectItem>
                            <SelectItem value="Low" className="min-h-[44px]">Low Priority</SelectItem>
                          </SelectContent>
                        </Select>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <div className="pt-2">
                    <Button 
                      type="submit" 
                      className="w-full min-h-[48px] bg-[#0D9488] hover:bg-[#0F766E] text-white font-semibold rounded-xl text-sm shadow-sm" 
                      disabled={form.formState.isSubmitting}
                    >
                      {form.formState.isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                      Save Reminder
                    </Button>
                  </div>
                </form>
              </Form>
            </DialogContent>
          </Dialog>
        </div>
      </CardHeader>
      
      <CardContent className="p-5 sm:p-6">
        {loading ? (
          <div className="flex justify-center p-12">
            <Loader2 className="h-8 w-8 animate-spin text-[#0D9488]" />
          </div>
        ) : sortedTasks.length === 0 ? (
          <div className="border-2 border-dashed border-slate-200 bg-slate-50/50 rounded-2xl p-12 flex flex-col items-center justify-center text-center">
            <CalendarIcon className="w-12 h-12 text-slate-300 mb-3" />
            <h4 className="font-semibold text-slate-800 text-base mb-1">No Pending Tasks</h4>
            <p className="text-sm text-slate-500 max-w-sm">
              You are all caught up! Click "Add Task Reminder" to schedule your next follow-up.
            </p>
          </div>
        ) : (
          <div className="space-y-3">
            {sortedTasks.map((task) => {
              const due = new Date(task.dueDate)
              const isOverdue = due.getTime() < Date.now()
              const isTodayTask = isToday(due)
              const contactInfo = getContactDisplay(task.contactId)

              return (
                <div 
                  key={task.id} 
                  className={`flex items-start gap-4 p-4 sm:p-5 rounded-2xl border transition-all duration-150 ${
                    isOverdue 
                      ? "bg-rose-50/70 border-rose-200/80 hover:bg-rose-100/60 shadow-xs" 
                      : isTodayTask
                      ? "bg-amber-50/50 border-amber-200/70 hover:bg-amber-100/50 shadow-xs"
                      : "bg-white border-slate-200/80 hover:bg-slate-50/70 shadow-xs"
                  }`}
                >
                  <Button 
                    variant="outline" 
                    size="icon" 
                    className="min-h-[44px] min-w-[44px] rounded-xl border-slate-200/90 bg-white hover:bg-slate-100 shrink-0 cursor-pointer"
                    disabled={togglingId === task.id}
                    onClick={() => handleToggle(task.id)}
                    title="Mark task as completed"
                  >
                    {togglingId === task.id ? (
                      <Loader2 className="h-5 w-5 animate-spin text-[#0D9488]" />
                    ) : (
                      <CheckSquare className="h-5 w-5 text-slate-400 hover:text-[#0D9488] transition-colors" />
                    )}
                  </Button>
                  
                  <div className="flex-1 space-y-1.5 min-w-0">
                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                      <div className="min-w-0">
                        <div className="flex items-center gap-1.5 truncate">
                          <Building2 className="w-3.5 h-3.5 text-[#0D9488] shrink-0" />
                          <span className="text-xs font-bold text-slate-900">{contactInfo.company}</span>
                          <span className="text-slate-400 text-xs">— {contactInfo.name}</span>
                          <Badge variant="outline" className="text-[10px] px-1.5 py-0 h-4 border-slate-200 text-slate-500 font-medium ml-1">
                            {contactInfo.role}
                          </Badge>
                        </div>
                        <p className="font-semibold text-slate-900 text-sm sm:text-base leading-snug mt-1 whitespace-pre-wrap break-words">
                          {task.title}
                        </p>
                      </div>
                      
                      <div className="flex items-center gap-2 shrink-0 self-start sm:self-center">
                        {isOverdue && (
                          <Badge variant="outline" className="bg-rose-100 text-rose-700 border-rose-300 font-semibold px-2.5 py-0.5 text-xs rounded-full flex items-center gap-1">
                            <AlertCircle className="w-3 h-3" />
                            Overdue
                          </Badge>
                        )}
                        {isTodayTask && !isOverdue && (
                          <Badge variant="outline" className="bg-amber-100 text-amber-700 border-amber-300 font-semibold px-2.5 py-0.5 text-xs rounded-full">
                            Due Today
                          </Badge>
                        )}
                        {getPriorityBadge(task.priority)}
                      </div>
                    </div>

                    <div className="flex items-center text-xs font-medium text-slate-500 gap-1.5 pt-1">
                      <Clock className={`w-3.5 h-3.5 ${isOverdue ? "text-rose-500" : "text-slate-400"}`} />
                      <span className={isOverdue ? "text-rose-600 font-semibold" : "text-slate-500"}>
                        Due: {format(due, "MMM d, yyyy 'at' h:mm a")}
                      </span>
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </CardContent>
    </Card>
  )
}
