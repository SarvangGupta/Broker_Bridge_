import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { getBrokerAssignmentsAction } from "@/src/server/actions/broker-actions"
import { Dialog, DialogContent, DialogTrigger, DialogTitle, DialogHeader } from "@/components/ui/dialog"
import { QuotationForm } from "@/src/components/forms/quotation-form"
import { AiMatchWorkspace } from "./ai-match-workspace"
import { Sparkles, FileText } from "lucide-react"

export async function AiMatchCenter() {
  const { data: assignments } = await getBrokerAssignmentsAction()
  
  const requirements = assignments?.filter((a: any) => a.type === 'Buyer Requirement') || []

  return (
    <div className="space-y-6">
      <Card className="w-full bg-white rounded-2xl border border-slate-200/80 shadow-sm overflow-hidden">
        <CardHeader className="border-b border-slate-100 pb-5">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-[#CCFBF1] flex items-center justify-center text-[#0D9488]">
              <Sparkles className="w-5 h-5" />
            </div>
            <div>
              <CardTitle className="text-xl font-bold text-slate-900">AI Match Engine</CardTitle>
              <CardDescription className="text-sm text-slate-500">
                Intelligent algorithm scoring commodity, grade, price proximity, and location.
              </CardDescription>
            </div>
          </div>
        </CardHeader>
        <CardContent className="pt-6">
          {requirements.length === 0 ? (
            <div className="p-12 text-center text-muted-foreground border-2 border-dashed border-slate-200 rounded-2xl bg-slate-50/50 flex flex-col items-center justify-center space-y-4">
              <div className="w-12 h-12 rounded-xl bg-slate-100 flex items-center justify-center text-slate-400">
                <FileText className="w-6 h-6" />
              </div>
              <div className="max-w-md">
                <h4 className="font-semibold text-slate-800 text-base mb-1">No Active Requirements</h4>
                <p className="text-sm text-slate-500">
                  You currently have no requirements assigned from the Admin Deal Desk. You can still draft a direct quotation manually.
                </p>
              </div>
              <Dialog>
                <DialogTrigger className="inline-flex items-center justify-center rounded-xl text-sm font-semibold transition-all bg-[#0D9488] text-white hover:bg-[#0F766E] shadow-sm h-11 px-5 py-2.5 cursor-pointer">
                  Draft Direct Quotation
                </DialogTrigger>
                <DialogContent className="sm:max-w-[480px]">
                  <DialogHeader>
                    <DialogTitle className="text-xl font-bold text-slate-900">Draft Direct Quotation</DialogTitle>
                  </DialogHeader>
                  <QuotationForm />
                </DialogContent>
              </Dialog>
            </div>
          ) : (
            <AiMatchWorkspace requirements={requirements} />
          )}
        </CardContent>
      </Card>
    </div>
  )
}
