import Link from "next/link";
import { Building2, Edit } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { CompanyStatusBadge } from "@/components/crm/company-status-badge";
import { DecisionRoleBadge } from "@/components/crm/decision-role-badge";
import { PrimaryContactBadge } from "@/components/crm/primary-contact-badge";
import { RelationshipLevelBadge } from "@/components/crm/relationship-level-badge";
import type { ContactPerson } from "@/lib/crm/types";

export function ContactDetailHeader({ contact }: { contact: ContactPerson }) {
  return (
    <Card>
      <CardContent className="flex flex-col gap-4 p-5 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <h1 className="text-2xl font-semibold tracking-normal">{contact.name}</h1>
            <PrimaryContactBadge primary={contact.is_primary} />
            <CompanyStatusBadge status={contact.status} />
          </div>
          <p className="mt-2 text-sm text-muted-foreground">
            {contact.designation ?? "No designation"} {contact.department ? `- ${contact.department}` : ""}
          </p>
          <div className="mt-4 flex flex-wrap gap-2">
            <DecisionRoleBadge role={contact.decision_role} />
            <RelationshipLevelBadge level={contact.relationship_level} />
            <span className="rounded-md border px-2.5 py-0.5 text-xs font-medium">
              {contact.preferred_contact_method ?? "No preferred method"}
            </span>
          </div>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button asChild variant="outline">
            <Link href={`/companies/${contact.company_id}`}>
              <Building2 />
              Company
            </Link>
          </Button>
          <Button asChild>
            <Link href={`/contacts/${contact.id}/edit`}>
              <Edit />
              Edit Contact
            </Link>
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
