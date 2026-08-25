import { getBrokerQuotationsAction } from "@/src/server/actions/quotation-actions"
import { QuotationForm } from "@/src/components/forms/quotation-form"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Button, buttonVariants } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { FileText } from "lucide-react"
import { QuotationTableActions } from "@/src/components/dashboard/quotation-table-actions"

export default async function BrokerQuotationsPage() {
  const { data: quotations } = await getBrokerQuotationsAction()

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold tracking-tight">Quotation Management</h1>
      
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="md:col-span-1">
          <Card>
            <CardHeader>
              <CardTitle>Draft New Quotation</CardTitle>
              <CardDescription>Create a new quote for a matched deal</CardDescription>
            </CardHeader>
            <CardContent>
              <QuotationForm />
            </CardContent>
          </Card>
        </div>
        
        <div className="md:col-span-2">
          <Card>
            <CardHeader>
              <CardTitle>Active Quotations</CardTitle>
              <CardDescription>Manage and download generated quotes</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="rounded-md border">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Quotation ID</TableHead>
                      <TableHead>Offered Price</TableHead>
                      <TableHead>Valid Until</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead className="text-right">Actions</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {(!quotations || quotations.length === 0) ? (
                      <TableRow>
                        <TableCell colSpan={5} className="text-center h-24 text-muted-foreground">
                          No quotations found. Draft one to get started.
                        </TableCell>
                      </TableRow>
                    ) : (
                      quotations.map((quote) => (
                        <TableRow key={quote.id}>
                          <TableCell className="font-medium text-xs">{quote.id.split('-')[0].toUpperCase()}</TableCell>
                          <TableCell>₹{quote.offeredPrice}</TableCell>
                          <TableCell>{new Date(quote.validUntil).toLocaleDateString()}</TableCell>
                          <TableCell>{quote.status}</TableCell>
                          <TableCell className="text-right">
                            <QuotationTableActions quote={quote} />
                          </TableCell>
                        </TableRow>
                      ))
                    )}
                  </TableBody>
                </Table>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
