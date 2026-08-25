import { z } from "zod";

export const quotationSchema = z.object({
  requirement_id: z.string().uuid("Invalid requirement ID"),
  seller_availability_id: z.string().uuid("Invalid seller availability ID"),
  offered_price: z.number().positive("Offered price must be a positive number"),
  valid_until: z.date().refine((date) => date > new Date(), {
    message: "Valid until date must be in the future",
  }),
});
