"use client";

import React, { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import {
  KeyRound,
  Loader2,
  Eye,
  EyeOff,
  Copy,
  Check,
  Sparkles,
  ShieldAlert,
  User,
  Mail,
} from "lucide-react";
import { forceResetUserPasswordByAdminAction } from "@/src/server/actions/admin-user-actions";

export interface TargetUserInfo {
  id?: string;
  name?: string | null;
  email?: string | null;
  role?: string | null;
}

interface ForceResetPasswordDialogProps {
  user?: TargetUserInfo;
  trigger?: React.ReactNode;
  onSuccess?: () => void;
}

export function ForceResetPasswordDialog({
  user,
  trigger,
  onSuccess,
}: ForceResetPasswordDialogProps) {
  const [open, setOpen] = useState(false);
  const [emailInput, setEmailInput] = useState(user?.email || "");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [copied, setCopied] = useState(false);

  // Generate an easy-to-read temporary testing password
  const handleGeneratePassword = () => {
    const randomDigits = Math.floor(1000 + Math.random() * 9000);
    const generated = `TestPass@${randomDigits}!`;
    setPassword(generated);
    setShowPassword(true);
    toast.info("Generated new testing password.");
  };

  const handleCopyPassword = async () => {
    if (!password) return;
    try {
      await navigator.clipboard.writeText(password);
      setCopied(true);
      toast.success("Password copied to clipboard!");
      setTimeout(() => setCopied(false), 2000);
    } catch {
      toast.error("Failed to copy password.");
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    const targetEmail = user?.email || emailInput.trim();
    const targetUserId = user?.id;

    if (!targetUserId && !targetEmail) {
      toast.error("Please enter a valid User Email or ID.");
      return;
    }

    if (!password || password.length < 6) {
      toast.error("New password must be at least 6 characters.");
      return;
    }

    setIsSubmitting(true);
    try {
      const res = await forceResetUserPasswordByAdminAction({
        userId: targetUserId,
        email: targetEmail,
        newPassword: password,
      });

      if (res.success) {
        toast.success("Password Forcefully Updated!", {
          description: `User can now log in immediately with: ${password}`,
        });
        setPassword("");
        setOpen(false);
        onSuccess?.();
      } else {
        toast.error(res.error || "Failed to reset password.");
      }
    } catch (err: any) {
      toast.error(err.message || "An unexpected error occurred.");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger
        render={
          trigger ? (
            (trigger as React.ReactElement)
          ) : (
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="h-9 px-3 gap-1.5 text-xs font-semibold text-amber-700 bg-amber-50/80 border-amber-200 hover:bg-amber-100 hover:text-amber-800 transition-colors cursor-pointer"
            >
              <KeyRound className="w-3.5 h-3.5" />
              <span>Reset Password</span>
            </Button>
          )
        }
      />

      <DialogContent className="w-[95vw] sm:max-w-md p-0 rounded-2xl border-slate-200 shadow-2xl bg-white overflow-hidden">
        <DialogHeader className="p-6 pb-4 border-b border-slate-100 bg-amber-50/40">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-amber-500 text-white flex items-center justify-center shadow-sm shrink-0">
              <KeyRound className="w-5 h-5" />
            </div>
            <div>
              <DialogTitle className="text-lg font-bold text-slate-900">
                Force Reset Password
              </DialogTitle>
              <DialogDescription className="text-xs text-slate-500 mt-0.5">
                Instantly overwrites Auth credentials using Super Admin God-Mode.
              </DialogDescription>
            </div>
          </div>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="p-6 space-y-5">
          {/* Target User Info or Email Input */}
          {user ? (
            <div className="p-3.5 bg-slate-50 border border-slate-200/80 rounded-xl space-y-1">
              <div className="text-[11px] font-bold uppercase tracking-wider text-slate-500 flex items-center gap-1.5">
                <User className="w-3.5 h-3.5 text-slate-400" />
                <span>Target User</span>
                {user.role && (
                  <span className="ml-auto text-[10px] font-bold uppercase px-2 py-0.5 rounded-full bg-slate-200 text-slate-700">
                    {user.role}
                  </span>
                )}
              </div>
              <div className="text-sm font-bold text-slate-800">
                {user.name || "Enterprise User"}
              </div>
              <div className="text-xs font-mono text-slate-600 flex items-center gap-1">
                <Mail className="w-3 h-3 text-slate-400" />
                <span>{user.email || user.id}</span>
              </div>
            </div>
          ) : (
            <div className="space-y-1.5">
              <Label className="text-xs font-semibold text-slate-700">User Email Address *</Label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                <Input
                  type="email"
                  placeholder="e.g. buyer@company.com"
                  value={emailInput}
                  onChange={(e) => setEmailInput(e.target.value)}
                  className="pl-9 h-11 text-sm bg-white"
                  required
                />
              </div>
            </div>
          )}

          {/* New Password Input with Generator & Visibility Toggle */}
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <Label className="text-xs font-semibold text-slate-700">New Password *</Label>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={handleGeneratePassword}
                className="h-7 px-2 text-xs text-amber-700 hover:text-amber-800 hover:bg-amber-50 gap-1 font-medium"
              >
                <Sparkles className="w-3 h-3 text-amber-500" />
                <span>Auto-Generate</span>
              </Button>
            </div>

            <div className="relative">
              <Input
                type={showPassword ? "text" : "password"}
                placeholder="Enter new password (min 6 chars)"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="pr-20 h-11 text-sm font-mono bg-white"
                required
                minLength={6}
              />
              <div className="absolute right-1.5 top-1/2 -translate-y-1/2 flex items-center gap-1">
                {password && (
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={handleCopyPassword}
                    className="h-8 w-8 p-0 text-slate-400 hover:text-slate-600"
                    title="Copy Password"
                  >
                    {copied ? (
                      <Check className="w-4 h-4 text-emerald-600" />
                    ) : (
                      <Copy className="w-4 h-4" />
                    )}
                  </Button>
                )}
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => setShowPassword(!showPassword)}
                  className="h-8 w-8 p-0 text-slate-400 hover:text-slate-600"
                  title={showPassword ? "Hide password" : "Show password"}
                >
                  {showPassword ? (
                    <EyeOff className="w-4 h-4" />
                  ) : (
                    <Eye className="w-4 h-4" />
                  )}
                </Button>
              </div>
            </div>
            <p className="text-[11px] text-slate-500">
              The user can immediately log in with this new password without needing email verification.
            </p>
          </div>

          <DialogFooter className="pt-2 border-t border-slate-100 flex flex-col-reverse sm:flex-row sm:justify-end gap-2.5">
            <Button
              type="button"
              variant="outline"
              onClick={() => setOpen(false)}
              disabled={isSubmitting}
              className="h-10 text-xs font-medium"
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={isSubmitting || !password || password.length < 6}
              className="h-10 text-xs font-semibold bg-amber-600 hover:bg-amber-700 text-white shadow-sm flex items-center justify-center gap-2 min-w-[150px] cursor-pointer"
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="w-3.5 h-3.5 animate-spin text-white" />
                  <span>Updating Password...</span>
                </>
              ) : (
                <>
                  <KeyRound className="w-3.5 h-3.5" />
                  <span>Set New Password</span>
                </>
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

