export interface RequirementStatusMeta {
  label: string
  badgeClass: string
  dotClass: string
}

export function formatBuyerRequirementStatus(status: string): RequirementStatusMeta {
  const normalized = (status || '').toLowerCase().trim()

  switch (normalized) {
    case 'open':
    case 'sourcing':
      return {
        label: 'Finding supply',
        badgeClass: 'bg-sky-50 text-[#0284C7] border-sky-200',
        dotClass: 'bg-[#0284C7]',
      }
    case 'proposed':
      return {
        label: 'New proposal',
        badgeClass: 'bg-indigo-50 text-indigo-700 border-indigo-200',
        dotClass: 'bg-indigo-600',
      }
    case 'negotiating':
      return {
        label: 'Negotiation in progress',
        badgeClass: 'bg-amber-50 text-amber-800 border-amber-200',
        dotClass: 'bg-amber-500 animate-pulse',
      }
    case 'awaiting confirmation':
      return {
        label: 'Awaiting confirmation',
        badgeClass: 'bg-purple-50 text-purple-700 border-purple-200',
        dotClass: 'bg-purple-600',
      }
    case 'draft':
      return {
        label: 'Draft',
        badgeClass: 'bg-slate-100 text-slate-700 border-slate-200',
        dotClass: 'bg-slate-400',
      }
    case 'booked':
    case 'accepted':
    case 'fulfilled':
      return {
        label: 'Order confirmed',
        badgeClass: 'bg-emerald-50 text-emerald-800 border-emerald-200',
        dotClass: 'bg-emerald-600',
      }
    case 'cancelled':
      return {
        label: 'Cancelled',
        badgeClass: 'bg-rose-50 text-rose-700 border-rose-200',
        dotClass: 'bg-rose-500',
      }
    default:
      return {
        label: status || 'Unknown',
        badgeClass: 'bg-slate-100 text-slate-700 border-slate-200',
        dotClass: 'bg-slate-400',
      }
  }
}
