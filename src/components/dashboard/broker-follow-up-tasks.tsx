'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { PhoneCall, Check, ArrowRight } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { toggleTaskStatusAction } from '@/src/server/actions/crm-actions';
import { BrokerFollowUpTask } from '@/src/server/actions/broker-dashboard-actions';

interface BrokerFollowUpTasksProps {
  initialTasks: BrokerFollowUpTask[];
}

export function BrokerFollowUpTasks({ initialTasks }: BrokerFollowUpTasksProps) {
  const [tasks, setTasks] = useState<BrokerFollowUpTask[]>(initialTasks);

  const toggleTaskCompleted = async (taskId: string) => {
    // Optimistic local state update
    setTasks((prev) =>
      prev.map((t) => (t.id === taskId ? { ...t, completed: !t.completed } : t))
    );

    try {
      await toggleTaskStatusAction(taskId);
    } catch (err) {
      console.error('Failed to toggle task status:', err);
    }
  };

  const pendingTasksCount = tasks.filter((t) => !t.completed).length;

  return (
    <Card className="bg-white border border-slate-200/80 shadow-2xs rounded-2xl overflow-hidden">
      <CardHeader className="p-4 sm:p-5 border-b border-slate-100 bg-slate-50/50 flex flex-row items-center justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <PhoneCall className="w-4 h-4 text-blue-600" />
            <CardTitle className="text-sm sm:text-base font-bold text-slate-900">
              Today&apos;s Follow-ups
            </CardTitle>
          </div>
          <CardDescription className="text-xs text-slate-500 mt-0.5">
            CRM reminders & trade call logs
          </CardDescription>
        </div>
        <span className="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold bg-blue-50 text-blue-700 border border-blue-200">
          {pendingTasksCount} Pending
        </span>
      </CardHeader>

      <CardContent className="p-3 sm:p-4 space-y-2.5">
        {tasks.length === 0 ? (
          <div className="p-6 rounded-xl border border-dashed border-slate-200 bg-slate-50/50 text-center space-y-2">
            <div className="w-8 h-8 rounded-full bg-slate-100 text-slate-400 flex items-center justify-center mx-auto">
              <Check className="w-4 h-4" />
            </div>
            <h4 className="text-xs font-bold text-slate-700">No Follow-ups Due Today</h4>
            <p className="text-[11px] text-slate-500">
              All CRM tasks and client calls for today have been completed.
            </p>
          </div>
        ) : (
          tasks.map((task) => {
            const isCompleted = task.completed;

            return (
              <div
                key={task.id}
                onClick={() => toggleTaskCompleted(task.id)}
                className={`group p-3 sm:p-3.5 rounded-xl border transition-all cursor-pointer flex items-start gap-3 select-none ${
                  isCompleted
                    ? 'border-slate-100 bg-slate-50/60 opacity-60'
                    : 'border-slate-200/70 bg-white hover:border-[#0D9488]/40 hover:shadow-2xs'
                }`}
              >
                {/* Quick "Mark Done" interactive toggle */}
                <button
                  type="button"
                  aria-label={isCompleted ? 'Mark as incomplete' : 'Mark as done'}
                  className={`mt-0.5 w-5 h-5 rounded-md flex items-center justify-center transition-all shrink-0 border ${
                    isCompleted
                      ? 'bg-[#0D9488] border-[#0D9488] text-white shadow-2xs'
                      : 'border-slate-300 bg-white group-hover:border-[#0D9488] text-transparent'
                  }`}
                >
                  <Check className="w-3.5 h-3.5 stroke-[3]" />
                </button>

                {/* Task Content */}
                <div className="min-w-0 flex-1 space-y-1">
                  <p
                    className={`text-xs sm:text-sm font-semibold leading-snug tracking-tight transition-all ${
                      isCompleted ? 'line-through text-slate-400' : 'text-slate-900'
                    }`}
                  >
                    {task.title}
                  </p>

                  <div className="flex flex-wrap items-center gap-2 text-[11px] text-slate-500">
                    <span className="font-medium text-slate-700 truncate">
                      {task.entity}
                    </span>
                    <span className="text-slate-300">•</span>
                    <span className="text-slate-500">{task.time}</span>
                    {task.priority === 'high' && !isCompleted && (
                      <span className="px-1.5 py-0.2 rounded text-[9px] font-bold uppercase tracking-wider bg-rose-50 text-rose-600 border border-rose-200">
                        High
                      </span>
                    )}
                  </div>
                </div>
              </div>
            );
          })
        )}

        {/* CRM Navigation Footer */}
        <div className="pt-2">
          <Link
            href="/broker/more"
            className="w-full min-h-[40px] text-xs font-semibold text-slate-700 hover:text-[#0D9488] hover:border-[#0D9488]/50 border border-slate-200 rounded-xl inline-flex items-center justify-center gap-1.5 hover:bg-slate-50 transition-all"
          >
            <span>Manage All CRM Contacts & Reminders</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </Link>
        </div>
      </CardContent>
    </Card>
  );
}
