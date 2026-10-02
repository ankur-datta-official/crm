import { Badge } from "@/components/ui/badge";

export function RatingBadge({ rating }: { rating: number | null }) {
  if (!rating) {
    return <Badge variant="secondary">Not rated</Badge>;
  }

  const variant = rating >= 8 ? "success" : rating >= 5 ? "warning" : "secondary";
  return <Badge variant={variant}>{rating}/10</Badge>;
}
