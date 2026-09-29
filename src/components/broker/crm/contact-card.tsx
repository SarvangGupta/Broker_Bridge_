'use client';

import React, { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  Building,
  Building2,
  User,
  Phone,
  Mail,
  Calendar,
  Clock,
  AlertTriangle,
  CheckCircle2,
  PhoneCall,
  Users as UsersIcon,
  FileText,
  Zap,
  ChevronRight,
  Layers,
  FileCheck2,
} from 'lucide-react';
import { ContactAggregatedProfilePayload } from '@/src/server/actions/broker-crm-actions';
import { CrmActivityDialog } from '@/src/components/forms/crm-activity-dialog';

interface ContactCardProps {
  profile: ContactAggregatedProfilePayload;
  onActivityLogged?: () => void;
}

export function ContactCard({ profile, onActivityLogged }: ContactCardProps) {
  const [isDialogOpen, setIsDialogOpen] = useState<boolean>(false);

  const getActivityIcon = (type: string) => {
    const t = type.toLowerCase();
    if (t.includes('call')) return <PhoneCall className="w-3.5 h-3.5 text-blue-600 shrink-0" />;
    if (t.includes('meeting')) return <UsersIcon className="w-3.5 h-3.5 text-purple-600 shrink-0" />;
    if (t.includes('task')) return <Calendar className="w-3.5 h-3.5 text-amber-600 shrink-0" />;
    return <FileText className="w-3.5 h-3.5 text-slate-500 shrink-0" />;
  };

  const formatFollowUpDate = (dateStr: string | null) => {
    if (!dateStr) return null;
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
    });
  };

  return (
    <Card className="border border-slate-200/80 bg-white shadow-xs hover:border-[#0D9488]/40 transition-all flex flex-col justify-between overflow-hidden">
      <CardContent className="p-4 sm:p-5 space-y-4">
        {/* HEADER: COMPANY & PERSON WITH ROLE BADGE */}
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0 flex-1 space-y-1">
            <div className="flex items-center gap-2 flex-wrap">
              <h3 className="font-bold text-slate-900 text-base leading-tight truncate">
                {profile.companyName}
              </h3>
              {/* Role Badge */}
              <Badge
                className={`text-[10px] font-bold px-2 py-0.5 border shrink-0 ${
                  profile.role === 'Buyer'
                    ? 'bg-blue-50 text-blue-800 border-blue-200'
                    : profile.role === 'Seller'
                    ? 'bg-teal-50 text-teal-800 border-teal-200'
                    : 'bg-slate-100 text-slate-700 border-slate-200'
                }`}
              >
                {profile.role === 'Buyer' && <Building className="w-3 h-3 mr-1 inline" />}
                {profile.role === 'Seller' && <Building2 className="w-3 h-3 mr-1 inline" />}
                {profile.role === 'Client' && <User className="w-3 h-3 mr-1 inline" />}
                {profile.role}
              </Badge>
            </div>
            <p className="text-xs text-slate-600 font-medium flex items-center gap-1.5 truncate">
              <User className="w-3.5 h-3.5 text-slate-400 shrink-0" />
              <span>{profile.userName}</span>
            </p>
          </div>
        </div>

        {/* CONTACT INFO PII BADGES */}
        {(profile.userMobile || profile.userEmail) && (
          <div className="flex items-center gap-3 text-[11px] text-slate-500 pt-0.5 border-t border-slate-100">
            {profile.userMobile && (
              <span className="flex items-center gap-1 font-mono">
                <Phone className="w-3 h-3 text-slate-400" />
                {profile.userMobile}
              </span>
            )}
            {profile.userEmail && (
              <span className="flex items-center gap-1 truncate max-w-[180px]">
                <Mail className="w-3 h-3 text-slate-400 shrink-0" />
                <span className="truncate">{profile.userEmail}</span>
              </span>
            )}
          </div>
        )}

        {/* TASK 2: KPI ROW (PILLS/BADGES FOR 360PX MOBILE FLEX-WRAP) */}
        <div className="flex items-center gap-2 flex-wrap text-xs pt-1">
          {/* Open Requirements Pill */}
          <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700 font-semibold border border-slate-200/80">
            <Layers className="w-3.5 h-3.5 text-[#0D9488]" />
            <span>{profile.openRequirementsCount} Requirements</span>
          </div>

          {/* Active Deals Pill */}
          <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700 font-semibold border border-slate-200/80">
            <FileCheck2 className="w-3.5 h-3.5 text-blue-600" />
            <span>{profile.activeDealsCount} Active Deals</span>
          </div>

          {/* Next Follow Up Pill */}
          {profile.nextFollowUpDate ? (
            <div
              className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg font-bold border ${
                profile.followUpStatus === 'OVERDUE'
                  ? 'bg-red-50 text-red-700 border-red-200 animate-pulse'
                  : profile.followUpStatus === 'TODAY'
                  ? 'bg-amber-50 text-amber-800 border-amber-300'
                  : 'bg-teal-50 text-teal-800 border-teal-200'
              }`}
            >
              {profile.followUpStatus === 'OVERDUE' ? (
                <AlertTriangle className="w-3.5 h-3.5 text-red-600 shrink-0" />
              ) : (
                <Clock className="w-3.5 h-3.5 shrink-0" />
              )}
              <span>
                {profile.followUpStatus === 'OVERDUE'
                  ? `Overdue: ${formatFollowUpDate(profile.nextFollowUpDate)}`
                  : profile.followUpStatus === 'TODAY'
                  ? 'Due Today'
                  : `Follow Up: ${formatFollowUpDate(profile.nextFollowUpDate)}`}
              </span>
            </div>
          ) : (
            <div className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-slate-50 text-slate-400 font-medium text-[11px]">
              No Task Set
            </div>
          )}
        </div>

        {/* TASK 2: HISTORY FEED (RECENT 3 ACTIVITIES) */}
        <div className="pt-2 border-t border-slate-100 space-y-2">
          <span className="text-[11px] font-bold uppercase tracking-wider text-slate-500 block">
            Interaction History
          </span>
          {profile.recentActivities.length === 0 ? (
            <p className="text-xs text-slate-400 italic py-1">No recorded activities yet.</p>
          ) : (
            <div className="space-y-1.5 max-h-36 overflow-y-auto pr-1">
              {profile.recentActivities.slice(0, 3).map((act) => (
                <div
                  key={act.id}
                  className="p-2 rounded-lg bg-slate-50 border border-slate-100 text-xs flex items-start gap-2"
                >
                  {getActivityIcon(act.type)}
                  <div className="min-w-0 flex-1 space-y-0.5">
                    <div className="flex items-center justify-between text-[11px]">
                      <span className="font-bold text-slate-800">{act.type}</span>
                      <span className="text-slate-400 text-[10px]">
                        {new Date(act.createdAt).toLocaleDateString('en-IN', {
                          day: '2-digit',
                          month: 'short',
                        })}
                      </span>
                    </div>
                    <p className="text-slate-600 text-[11px] line-clamp-1">{act.notes}</p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* TASK 3: ONE-TAP FOLLOW UP BUTTON */}
        <div className="pt-2">
          <CrmActivityDialog
            defaultContactId={profile.contactId}
            open={isDialogOpen}
            onOpenChange={setIsDialogOpen}
            onLogged={() => {
              if (onActivityLogged) onActivityLogged();
            }}
            customTrigger={
              <Button
                onClick={() => setIsDialogOpen(true)}
                className="w-full bg-[#0D9488] hover:bg-teal-700 text-white font-semibold text-xs h-10 rounded-xl cursor-pointer shadow-xs flex items-center justify-center gap-1.5"
              >
                <Zap className="w-4 h-4 fill-white text-white" />
                One-Tap Follow Up
              </Button>
            }
          />
        </div>
      </CardContent>
    </Card>
  );
}
