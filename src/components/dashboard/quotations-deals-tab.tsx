import { getBrokerQuotationsAction } from "@/src/server/actions/quotation-actions"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Card, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { QuotationTableActions } from "@/src/components/dashboard/quotation-table-actions"
import { BrokerAssignments } from "@/src/components/dashboard/broker-assignments"
import { DraftQuotationSheet } from "@/src/components/dialogs/draft-quotation-sheet"
import { Layers, FileText, CheckCircle2 } from "lucide-react"

export async function QuotationsDealsTab() {
  const { data: quotations } = await getBrokerQuotationsAction()
  const activeQuotes = quotations || []

  return (
    <Card className="w-full bg-white rounded-2xl border border-slate-200/80 shadow-sm overflow-hidden">
      {/* HEADER ROW WITH ACTION CTA */}
      <div className="p-5 sm:p-6 border-b border-slate-100 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-[#CCFBF1] flex items-center justify-center text-[#0D9488] shrink-0">
            <Layers className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-xl font-bold text-slate-900 leading-tight">Transaction Pipeline</h2>
            <p className="text-sm text-slate-500 mt-0.5">
              Manage active quotes, counteroffers, and booked commodity contracts.
            </p>
          </div>
        </div>
        <div className="w-full sm:w-auto flex justify-end">
          <DraftQuotationSheet />
        </div>
      </div>

      {/* UNIFIED SUB-TABS */}
      <Tabs defaultValue="quotations" className="w-full">
        <div className="px-5 sm:px-6 pt-3 border-b border-slate-100 bg-slate-50/60 overflow-x-auto">
          <TabsList className="bg-transparent h-auto p-0 gap-6 border-none flex whitespace-nowrap">
            <TabsTrigger 
              value="quotations" 
              className="data-[state=active]:border-b-2 data-[state=active]:border-[#0D9488] data-[state=active]:text-[#0D9488] data-[state=active]:bg-transparent data-[state=active]:shadow-none bg-transparent rounded-none px-1 pb-3 font-semibold text-slate-500 text-sm cursor-pointer transition-colors flex items-center gap-2"
            >
              <FileText className="w-4 h-4" />
              <span>Pending Quotations</span>
              <span className="ml-1 px-2 py-0.5 text-xs rounded-full bg-slate-200/70 data-[state=active]:bg-[#CCFBF1] data-[state=active]:text-[#0D9488] font-mono tabular-nums">
                {activeQuotes.length}
              </span>
            </TabsTrigger>
            <TabsTrigger 
              value="deals" 
              className="data-[state=active]:border-b-2 data-[state=active]:border-[#0D9488] data-[state=active]:text-[#0D9488] data-[state=active]:bg-transparent data-[state=active]:shadow-none bg-transparent rounded-none px-1 pb-3 font-semibold text-slate-500 text-sm cursor-pointer transition-colors flex items-center gap-2"
            >
              <CheckCircle2 className="w-4 h-4" />
              <span>Booked Deals & Assignments</span>
            </TabsTrigger>
          </TabsList>
        </div>

        <CardContent className="p-5 sm:p-6">
          {/* TAB 1: PENDING QUOTATIONS */}
          <TabsContent value="quotations" className="mt-0 outline-none">
            {activeQuotes.length === 0 ? (
              <div className="border-2 border-dashed border-slate-200 bg-slate-50/50 rounded-2xl p-12 flex flex-col items-center justify-center text-center">
                <FileText className="w-12 h-12 text-slate-300 mb-3" />
                <h4 className="font-semibold text-slate-800 text-base mb-1">No Active Quotations</h4>
                <p className="text-sm text-slate-500 max-w-sm mb-4">
                  You have not generated any quotations yet. Click the Draft Quotation button above to create one.
                </p>
                <DraftQuotationSheet />
              </div>
            ) : (
              <>
                {/* MOBILE VIEW (< md) */}
                <div className="md:hidden space-y-4">
                  {activeQuotes.map((quote) => (
                    <div 
                      key={quote.id} 
                      className="bg-white rounded-2xl border border-slate-200/80 p-5 shadow-sm space-y-3"
                    >
                      <div className="flex items-center justify-between gap-2">
                        <span className="font-mono text-xs font-bold text-slate-500">
                          #{quote.id.split('-')[0].toUpperCase()}
                        </span>
                        <Badge 
                          variant="outline"
                          className={
                            quote.status === 'Accepted' ? 'bg-[#ECFDF5] text-[#047857] border-emerald-200/80 font-semibold px-2.5 py-0.5 text-xs rounded-full' :
                            quote.status === 'Sent' ? 'bg-[#EFF6FF] text-[#1D4ED8] border-blue-200/80 font-semibold px-2.5 py-0.5 text-xs rounded-full' :
                            quote.status === 'Countered' ? 'bg-[#FEF3C7] text-[#B45309] border-amber-200/80 font-semibold px-2.5 py-0.5 text-xs rounded-full' :
                            'bg-[#F1F5F9] text-[#475569] border-slate-200 font-semibold px-2.5 py-0.5 text-xs rounded-full'
                          }
                        >
                          {quote.status}
                        </Badge>
                      </div>

                      <div className="grid grid-cols-2 gap-3 py-3 px-3.5 bg-slate-50/80 rounded-xl border border-slate-100">
                        <div>
                          <div className="text-[11px] font-semibold text-slate-600 uppercase">Offered Price</div>
                          {quote.counterPrice ? (
                            <div className="flex flex-col">
                              <span className="line-through text-slate-400 text-xs font-mono">₹{quote.offeredPrice}</span>
                              <span className="text-amber-600 font-bold font-mono text-base tabular-nums">
                                ₹{quote.counterPrice}
                              </span>
                            </div>
                          ) : (
                            <div className="text-lg font-mono font-bold text-[#0D9488] tabular-nums">
                              ₹{quote.offeredPrice}
                            </div>
                          )}
                        </div>
                        <div>
                          <div className="text-[11px] font-semibold text-slate-600 uppercase">Valid Until</div>
                          <div className="text-sm font-medium text-slate-700 mt-1">
                            {new Date(quote.validUntil).toLocaleDateString()}
                          </div>
                        </div>
                      </div>

                      <div className="pt-1 flex justify-end">
                        <QuotationTableActions quote={quote} />
                      </div>
                    </div>
                  ))}
                </div>

                {/* DESKTOP TABLE VIEW (>= md) */}
                <div className="hidden md:block rounded-xl border border-slate-200/80 overflow-hidden bg-white">
                  <Table>
                    <TableHeader>
                      <TableRow className="bg-slate-50/80 hover:bg-slate-50/80 border-b border-slate-200">
                        <TableHead className="font-semibold text-slate-600">Quotation ID</TableHead>
                        <TableHead className="font-semibold text-slate-600">Offered Price</TableHead>
                        <TableHead className="font-semibold text-slate-600">Valid Until</TableHead>
                        <TableHead className="font-semibold text-slate-600 text-center">Status</TableHead>
                        <TableHead className="text-right font-semibold text-slate-600">Actions</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {activeQuotes.map((quote) => (
                        <TableRow key={quote.id} className="hover:bg-slate-50/50 transition-colors">
                          <TableCell className="font-mono text-xs font-semibold text-slate-500">
                            {quote.id.split('-')[0].toUpperCase()}
                          </TableCell>
                          <TableCell>
                            {quote.counterPrice ? (
                              <div className="flex flex-col">
                                <span className="line-through text-slate-400 text-xs font-mono">₹{quote.offeredPrice}</span>
                                <span className="text-amber-600 font-bold font-mono text-sm">
                                  ₹{quote.counterPrice} <span className="text-[10px] font-normal text-slate-500 ml-1">(Counter)</span>
                                </span>
                              </div>
                            ) : (
                              <span className="font-bold text-slate-900 font-mono text-sm">₹{quote.offeredPrice}</span>
                            )}
                          </TableCell>
                          <TableCell className="text-xs text-slate-500 font-medium">
                            {new Date(quote.validUntil).toLocaleDateString()}
                          </TableCell>
                          <TableCell className="text-center">
                            <Badge 
                              variant="outline"
                              className={
                                quote.status === 'Accepted' ? 'bg-[#ECFDF5] text-[#047857] border-emerald-200/80 font-semibold px-2.5 py-0.5 text-xs rounded-full' :
                                quote.status === 'Sent' ? 'bg-[#EFF6FF] text-[#1D4ED8] border-blue-200/80 font-semibold px-2.5 py-0.5 text-xs rounded-full' :
                                quote.status === 'Countered' ? 'bg-[#FEF3C7] text-[#B45309] border-amber-200/80 font-semibold px-2.5 py-0.5 text-xs rounded-full' :
                                'bg-[#F1F5F9] text-[#475569] border-slate-200 font-semibold px-2.5 py-0.5 text-xs rounded-full'
                              }
                            >
                              {quote.status}
                            </Badge>
                          </TableCell>
                          <TableCell className="text-right">
                            <QuotationTableActions quote={quote} />
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              </>
            )}
          </TabsContent>

          {/* TAB 2: BOOKED DEALS & ASSIGNMENTS */}
          <TabsContent value="deals" className="mt-0 outline-none">
            <BrokerAssignments embedded={true} />
          </TabsContent>
        </CardContent>
      </Tabs>
    </Card>
  )
}
