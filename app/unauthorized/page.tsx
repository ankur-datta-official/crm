import { CircleX } from "lucide-react";
import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function UnauthorizedPage() {
  return (
    <div className="flex min-h-[400px] flex-col items-center justify-center text-center">
      <div className="rounded-full bg-destructive/10 p-6">
        <CircleX className="h-12 w-12 text-destructive" />
      </div>
      <h1 className="mt-6 text-2xl font-bold">Access Denied</h1>
      <p className="mt-2 max-w-md text-muted-foreground">
        You do not have permission to access this page. Contact your organization admin if you believe this is an error.
      </p>
      <div className="mt-8 flex gap-4">
        <Button asChild variant="outline">
          <Link href="/">Go Back</Link>
        </Button>
        <Button asChild>
          <Link href="/dashboard">Dashboard</Link>
        </Button>
      </div>
    </div>
  );
}