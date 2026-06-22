import React from "react"
import { cn } from "@/src/lib/utils"

function Skeleton({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="skeleton"
      className={cn("luxury-shimmer rounded-md", className)}
      {...props}
    />
  )
}

export { Skeleton }
