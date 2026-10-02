import Link from "next/link";
import { Search } from "lucide-react";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { globalSearch, type GlobalSearchItem } from "@/lib/search/global-search";

type SearchPageProps = {
  searchParams?: Promise<{
    q?: string;
  }>;
};

const SECTION_LABELS = {
  companies: "Companies",
  contacts: "Contacts",
  meetings: "Meetings",
  followups: "Follow-ups",
  documents: "Documents",
  helpRequests: "Help Requests",
} as const;

export default async function SearchPage({ searchParams }: SearchPageProps) {
  const resolvedSearchParams = searchParams ? await searchParams : undefined;
  const query = resolvedSearchParams?.q?.trim() ?? "";
  const results = await globalSearch(query, 20);
  const sections = [
    { key: "companies", label: SECTION_LABELS.companies, items: results.companies },
    { key: "contacts", label: SECTION_LABELS.contacts, items: results.contacts },
    { key: "meetings", label: SECTION_LABELS.meetings, items: results.meetings },
    { key: "followups", label: SECTION_LABELS.followups, items: results.followups },
    { key: "documents", label: SECTION_LABELS.documents, items: results.documents },
    { key: "helpRequests", label: SECTION_LABELS.helpRequests, items: results.helpRequests },
  ] as const;
  const totalResults = sections.reduce((sum, section) => sum + section.items.length, 0);

  return (
    <div className="space-y-6">
      <PageHeader
        title="Search"
        description={
          query.length >= 2
            ? `Showing grouped CRM results for "${query}".`
            : "Search across companies, contacts, meetings, follow-ups, documents, and help requests."
        }
      />

      {query.length < 2 ? (
        <EmptyState
          title="Start with at least 2 characters"
          description="Use the global search bar or add a query to the URL to search across your CRM workspace."
          icon={Search}
        />
      ) : totalResults === 0 ? (
        <EmptyState
          title="No results found"
          description="Try a different keyword, company name, email, mobile number, or discussion phrase."
          icon={Search}
        />
      ) : (
        <div className="grid gap-4 xl:grid-cols-2">
          {sections.map((section) => (
            <Card key={section.key}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0">
                <CardTitle>{section.label}</CardTitle>
                <Badge variant="secondary">{section.items.length}</Badge>
              </CardHeader>
              <CardContent>
                {section.items.length === 0 ? (
                  <p className="text-sm text-muted-foreground">No matches in this module.</p>
                ) : (
                  <div className="space-y-3">
                    {section.items.map((item) => (
                      <SearchResultRow key={item.id} item={item} />
                    ))}
                  </div>
                )}
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

function SearchResultRow({ item }: { item: GlobalSearchItem }) {
  return (
    <Link
      href={item.href}
      className="block rounded-lg border p-3 transition-colors hover:border-primary/40 hover:bg-muted/30"
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="truncate font-medium">{item.title}</p>
          <p className="mt-1 line-clamp-2 text-sm text-muted-foreground">{item.subtitle}</p>
        </div>
        {item.badge ? (
          <Badge variant="outline" className="shrink-0 capitalize">
            {item.badge}
          </Badge>
        ) : null}
      </div>
    </Link>
  );
}
