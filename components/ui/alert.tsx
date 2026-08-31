import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "@/lib/utils"

const alertVariants = cva(
  "relative w-full rounded-2xl border p-4 sm:p-5 [&>svg~*]:pl-8 [&>svg+div]:translate-y-[-3px] [&>svg]:absolute [&>svg]:left-4 [&>svg]:top-4 sm:[&>svg]:top-5 [&>svg]:text-foreground",
  {
    variants: {
      variant: {
        default: "bg-white text-slate-900 border-slate-200/90 shadow-xs",
        destructive:
          "border-rose-200 bg-rose-50/80 text-rose-900 dark:border-rose-500 [&>svg]:text-rose-600 shadow-xs",
        warning:
          "border-amber-200 bg-amber-50/80 text-amber-900 [&>svg]:text-amber-600 shadow-xs",
        success:
          "border-emerald-200 bg-emerald-50/80 text-emerald-900 [&>svg]:text-[#047857] shadow-xs",
        info:
          "border-blue-200 bg-blue-50/80 text-blue-900 [&>svg]:text-blue-600 shadow-xs",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  }
)

const Alert = React.forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement> & VariantProps<typeof alertVariants>
>(({ className, variant, ...props }, ref) => (
  <div
    ref={ref}
    role="alert"
    className={cn(alertVariants({ variant }), className)}
    {...props}
  />
))
Alert.displayName = "Alert"

const AlertTitle = React.forwardRef<
  HTMLParagraphElement,
  React.HTMLAttributes<HTMLHeadingElement>
>(({ className, ...props }, ref) => (
  <h5
    ref={ref}
    className={cn("mb-1 font-bold leading-none tracking-tight text-sm sm:text-base", className)}
    {...props}
  />
))
AlertTitle.displayName = "AlertTitle"

const AlertDescription = React.forwardRef<
  HTMLParagraphElement,
  React.HTMLAttributes<HTMLParagraphElement>
>(({ className, ...props }, ref) => (
  <div
    ref={ref}
    className={cn("text-xs sm:text-sm text-slate-600 [&_p]:leading-relaxed", className)}
    {...props}
  />
))
AlertDescription.displayName = "AlertDescription"

export { Alert, AlertTitle, AlertDescription }
