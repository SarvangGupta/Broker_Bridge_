"use client";

import React, { useState, useEffect } from "react";
import { format } from "date-fns";
import {
  Users,
  UserPlus,
  Search,
  ShieldCheck,
  CheckCircle2,
  XCircle,
  Loader2,
  Mail,
  Phone,
  Lock,
  Sparkles,
  Building2,
  RefreshCw,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { toast } from "sonner";
import {
  createBrokerByAdminAction,
  getAdminBrokersListAction,
} from "@/src/server/actions/admin-user-actions";

export interface BrokerUserRecord {
  id: string;
  name: string;
  email: string;
  mobile?: string | null;
  status: boolean;
  createdAt: string | Date;
}

export function AdminBrokersVault() {
  const [brokers, setBrokers] = useState<BrokerUserRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");

  // Add Broker Modal state
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Form inputs
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [phone, setPhone] = useState("");

  const loadBrokersData = async () => {
    setIsLoading(true);
    try {
      const res = await getAdminBrokersListAction();
      if (res.success && res.data) {
        setBrokers(res.data);
      } else {
        toast.error(res.error || "Failed to load brokers list.");
      }
    } catch (err: any) {
      toast.error(err.message || "An error occurred fetching brokers.");
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadBrokersData();
  }, []);

  const resetForm = () => {
    setName("");
    setEmail("");
    setPassword("");
    setPhone("");
  };

  const handleOpenChange = (open: boolean) => {
    setIsDialogOpen(open);
    if (!open) resetForm();
  };

  const handleCreateBroker = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !email.trim() || !password.trim()) {
      toast.error("Please fill in all required fields.");
      return;
    }

    if (password.length < 6) {
      toast.error("Temporary password must be at least 6 characters.");
      return;
    }

    setIsSubmitting(true);
    try {
      const res = await createBrokerByAdminAction({
        name: name.trim(),
        email: email.trim(),
        password: password.trim(),
        phone: phone.trim() || undefined,
      });

      if (res.success) {
        toast.success(res.message || "Broker account provisioned successfully!");
        handleOpenChange(false);
        loadBrokersData();
      } else {
        toast.error(res.error || "Failed to create broker account.");
      }
    } catch (err: any) {
      toast.error(err.message || "An unexpected error occurred.");
    } finally {
      setIsSubmitting(false);
    }
  };

  const filteredBrokers = brokers.filter((b) => {
    const q = searchQuery.toLowerCase();
    return (
      b.name.toLowerCase().includes(q) ||
      b.email.toLowerCase().includes(q) ||
      (b.mobile && b.mobile.toLowerCase().includes(q))
    );
  });

  return (
    <div className="space-y-6">
      {/* 1. TOP HEADER & PROVISION BUTTON */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 bg-white p-6 rounded-2xl border border-slate-200/90 shadow-xs">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-xl sm:text-2xl font-extrabold text-slate-900 tracking-tight">
              Invite-Only Brokers Vault
            </h2>
            <Badge variant="outline" className="bg-emerald-50 text-[#047857] border-emerald-200 font-bold text-xs">
              Enterprise Control
            </Badge>
          </div>
          <p className="text-xs sm:text-sm text-slate-500 mt-1">
            Provision verified Broker accounts and manage institutional desk credentials.
          </p>
        </div>

        <div className="flex items-center gap-3 w-full sm:w-auto">
          <Button
            variant="outline"
            size="sm"
            onClick={loadBrokersData}
            disabled={isLoading}
            className="h-11 rounded-xl text-slate-700 border-slate-200 hover:bg-slate-50 font-semibold text-xs gap-1.5 cursor-pointer"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${isLoading ? "animate-spin" : ""}`} />
            <span>Refresh</span>
          </Button>

          {/* ADD BROKER DIALOG */}
          <Dialog open={isDialogOpen} onOpenChange={handleOpenChange}>
            <DialogTrigger
              render={
                <Button className="h-11 min-h-[44px] px-5 bg-slate-900 hover:bg-slate-800 text-white font-bold rounded-xl text-xs sm:text-sm gap-2 shadow-xs cursor-pointer">
                  <UserPlus className="h-4 w-4 text-emerald-400" />
                  <span>Add New Broker</span>
                </Button>
              }
            />

            <DialogContent className="sm:max-w-[480px] p-0 rounded-2xl border-slate-200 overflow-hidden">
              <DialogHeader className="p-6 pb-4 border-b border-slate-100 bg-slate-50/70">
                <div className="flex items-center gap-3">
                  <div className="h-10 w-10 rounded-xl bg-slate-900 text-emerald-400 flex items-center justify-center shrink-0">
                    <UserPlus className="h-5 w-5" />
                  </div>
                  <div>
                    <DialogTitle className="text-lg font-bold text-slate-900">
                      Provision Broker Account
                    </DialogTitle>
                    <DialogDescription className="text-xs text-slate-500 mt-0.5">
                      Create an invite-only broker account. The broker can log in immediately at /login.
                    </DialogDescription>
                  </div>
                </div>
              </DialogHeader>

              <form onSubmit={handleCreateBroker} className="p-6 space-y-4">
                <div className="space-y-1.5">
                  <Label htmlFor="broker-name" className="text-xs font-bold text-slate-700">
                    Full Name <span className="text-rose-500">*</span>
                  </Label>
                  <Input
                    id="broker-name"
                    placeholder="e.g. Rajesh Kumar"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    required
                    className="h-11 rounded-xl bg-slate-50 border-slate-200 text-sm"
                  />
                </div>

                <div className="space-y-1.5">
                  <Label htmlFor="broker-email" className="text-xs font-bold text-slate-700">
                    Email Address <span className="text-rose-500">*</span>
                  </Label>
                  <Input
                    id="broker-email"
                    type="email"
                    placeholder="broker@domain.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                    className="h-11 rounded-xl bg-slate-50 border-slate-200 text-sm"
                  />
                </div>

                <div className="space-y-1.5">
                  <Label htmlFor="broker-password" className="text-xs font-bold text-slate-700">
                    Temporary Password <span className="text-rose-500">*</span>
                  </Label>
                  <Input
                    id="broker-password"
                    type="text"
                    placeholder="Min 6 characters"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    className="h-11 rounded-xl bg-slate-50 border-slate-200 text-sm font-mono"
                  />
                </div>

                <div className="space-y-1.5">
                  <Label htmlFor="broker-phone" className="text-xs font-bold text-slate-700">
                    Phone / WhatsApp Number (Optional)
                  </Label>
                  <Input
                    id="broker-phone"
                    placeholder="+91 98765 43210"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    className="h-11 rounded-xl bg-slate-50 border-slate-200 text-sm"
                  />
                </div>

                <DialogFooter className="pt-4 border-t border-slate-100 flex gap-2">
                  <Button
                    type="button"
                    variant="outline"
                    onClick={() => handleOpenChange(false)}
                    disabled={isSubmitting}
                    className="rounded-xl h-11 text-xs font-semibold"
                  >
                    Cancel
                  </Button>

                  <Button
                    type="submit"
                    disabled={isSubmitting}
                    className="rounded-xl h-11 px-5 bg-slate-900 hover:bg-slate-800 text-white font-bold text-xs gap-2 flex-1 cursor-pointer"
                  >
                    {isSubmitting ? (
                      <>
                        <Loader2 className="h-4 w-4 animate-spin text-emerald-400" />
                        <span>Provisioning Workspace...</span>
                      </>
                    ) : (
                      <>
                        <UserPlus className="h-4 w-4 text-emerald-400" />
                        <span>Create Broker Account</span>
                      </>
                    )}
                  </Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* 2. SEARCH BAR & TABLE CARD */}
      <Card className="rounded-2xl border-slate-200 shadow-xs bg-white overflow-hidden">
        <CardHeader className="p-5 border-b border-slate-100 bg-slate-50/50 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div>
            <CardTitle className="text-base font-bold text-slate-900">
              Registered Broker Desks ({brokers.length})
            </CardTitle>
            <CardDescription className="text-xs text-slate-500">
              Active broker credentials authorized for enterprise deal matching.
            </CardDescription>
          </div>

          <div className="relative w-full sm:w-72">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
            <Input
              placeholder="Search by name, email or phone..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9 h-10 rounded-xl bg-white border-slate-200 text-xs"
            />
          </div>
        </CardHeader>

        <CardContent className="p-0">
          {isLoading ? (
            <div className="flex items-center justify-center py-16 text-slate-400 gap-2">
              <Loader2 className="h-5 w-5 animate-spin text-emerald-600" />
              <span className="text-xs font-semibold">Loading Broker Accounts...</span>
            </div>
          ) : filteredBrokers.length === 0 ? (
            <div className="p-12 text-center flex flex-col items-center justify-center">
              <div className="h-12 w-12 rounded-2xl bg-slate-100 flex items-center justify-center text-slate-400 mb-3">
                <Users className="h-6 w-6 stroke-[1.75]" />
              </div>
              <h3 className="text-sm font-bold text-slate-900">No broker accounts found</h3>
              <p className="text-xs text-slate-500 max-w-sm mt-1">
                {searchQuery ? "No brokers matching your search query." : "Click 'Add New Broker' to provision your first broker workspace."}
              </p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader className="bg-slate-50/80">
                  <TableRow className="border-slate-100">
                    <TableHead className="font-bold text-xs text-slate-700">Broker Name</TableHead>
                    <TableHead className="font-bold text-xs text-slate-700">Email Address</TableHead>
                    <TableHead className="font-bold text-xs text-slate-700">Phone / WhatsApp</TableHead>
                    <TableHead className="font-bold text-xs text-slate-700">Status</TableHead>
                    <TableHead className="font-bold text-xs text-slate-700">Provisioned Date</TableHead>
                  </TableRow>
                </TableHeader>

                <TableBody>
                  {filteredBrokers.map((broker) => (
                    <TableRow key={broker.id} className="hover:bg-slate-50/70 border-slate-100">
                      <TableCell className="font-bold text-sm text-slate-900">
                        <div className="flex items-center gap-2.5">
                          <div className="w-8 h-8 rounded-full bg-slate-900 text-emerald-400 font-bold flex items-center justify-center text-xs shrink-0">
                            {broker.name[0]?.toUpperCase() || "B"}
                          </div>
                          <span>{broker.name}</span>
                        </div>
                      </TableCell>

                      <TableCell className="text-xs font-mono text-slate-600">
                        <div className="flex items-center gap-1.5">
                          <Mail className="h-3.5 w-3.5 text-slate-400" />
                          <span>{broker.email}</span>
                        </div>
                      </TableCell>

                      <TableCell className="text-xs font-medium text-slate-600">
                        {broker.mobile ? (
                          <div className="flex items-center gap-1.5">
                            <Phone className="h-3.5 w-3.5 text-slate-400" />
                            <span>{broker.mobile}</span>
                          </div>
                        ) : (
                          <span className="text-slate-400 italic">Not set</span>
                        )}
                      </TableCell>

                      <TableCell>
                        <Badge
                          variant="outline"
                          className="bg-emerald-50 text-[#047857] border-emerald-200 font-bold text-[11px] gap-1 px-2 py-0.5"
                        >
                          <ShieldCheck className="h-3 w-3" />
                          <span>Active Broker</span>
                        </Badge>
                      </TableCell>

                      <TableCell className="text-xs text-slate-500 font-medium">
                        {broker.createdAt
                          ? format(new Date(broker.createdAt), "MMM d, yyyy")
                          : "N/A"}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
