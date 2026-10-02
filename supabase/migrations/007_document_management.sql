-- 007_document_management.sql
-- Implement Document Upload & Submission Tracking Module

-- 1. Create documents table
CREATE TABLE IF NOT EXISTS public.documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    contact_person_id UUID REFERENCES public.contact_persons(id) ON DELETE SET NULL,
    interaction_id UUID REFERENCES public.interactions(id) ON DELETE SET NULL,
    followup_id UUID REFERENCES public.followups(id) ON DELETE SET NULL,
    
    document_type TEXT NOT NULL DEFAULT 'Other',
    title TEXT NOT NULL,
    description TEXT,
    
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_url TEXT,
    file_size_mb NUMERIC,
    mime_type TEXT,
    file_extension TEXT,
    
    status TEXT DEFAULT 'submitted',
    submitted_to TEXT,
    submitted_at TIMESTAMPTZ,
    expiry_date DATE,
    remarks TEXT,
    
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    uploaded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create document_download_logs table
CREATE TABLE IF NOT EXISTS public.document_download_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
    downloaded_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Enable RLS
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_download_logs ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS Policies for documents
DROP POLICY IF EXISTS "Users can view documents from their organization" ON public.documents;
CREATE POLICY "Users can view documents from their organization"
    ON public.documents FOR SELECT
    USING (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can create documents for their organization" ON public.documents;
CREATE POLICY "Users can create documents for their organization"
    ON public.documents FOR INSERT
    WITH CHECK (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can update documents from their organization" ON public.documents;
CREATE POLICY "Users can update documents from their organization"
    ON public.documents FOR UPDATE
    USING (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can delete documents from their organization" ON public.documents;
CREATE POLICY "Users can delete documents from their organization"
    ON public.documents FOR DELETE
    USING (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

-- 5. Create RLS Policies for document_download_logs
DROP POLICY IF EXISTS "Users can view document_download_logs from their organization" ON public.document_download_logs;
CREATE POLICY "Users can view document_download_logs from their organization"
    ON public.document_download_logs FOR SELECT
    USING (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can insert document_download_logs for their organization" ON public.document_download_logs;
CREATE POLICY "Users can insert document_download_logs for their organization"
    ON public.document_download_logs FOR INSERT
    WITH CHECK (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

-- 6. Add updated_at trigger for documents
DROP TRIGGER IF EXISTS update_documents_updated_at ON public.documents;
CREATE TRIGGER update_documents_updated_at
    BEFORE UPDATE ON public.documents
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_updated_by();

-- 7. Add validation function for document relations
CREATE OR REPLACE FUNCTION public.validate_document_relations()
RETURNS TRIGGER AS $$
BEGIN
    -- Validate company belongs to same organization
    IF NEW.company_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.companies WHERE id = NEW.company_id AND organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION 'Company must belong to the same organization';
    END IF;

    -- Validate contact_person belongs to same company and organization
    IF NEW.contact_person_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.contact_persons WHERE id = NEW.contact_person_id AND company_id = NEW.company_id AND organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION 'Contact person must belong to the same company and organization';
    END IF;

    -- Validate interaction belongs to same company and organization
    IF NEW.interaction_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.interactions WHERE id = NEW.interaction_id AND company_id = NEW.company_id AND organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION 'Interaction must belong to the same company and organization';
    END IF;

    -- Validate followup belongs to same company and organization
    IF NEW.followup_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.followups WHERE id = NEW.followup_id AND company_id = NEW.company_id AND organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION 'Follow-up must belong to the same company and organization';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS validate_document_relations_trigger ON public.documents;
CREATE TRIGGER validate_document_relations_trigger
    BEFORE INSERT OR UPDATE ON public.documents
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_document_relations();

-- 8. Create storage bucket for documents (Documentation for manual step)
-- Bucket: crm-documents
-- Folder structure: organization_id/company_id/document_id/original-file-name

-- Note: Storage RLS policies should be added after creating the bucket.
-- Recommended SQL for Storage RLS (if bucket exists):
-- insert into storage.buckets (id, name, public) values ('crm-documents', 'crm-documents', false);
-- create policy "Authenticated users can upload documents to their organization folder"
-- on storage.objects for insert to authenticated with check (
--   bucket_id = 'crm-documents' AND (storage.foldername(name))[1] = (select organization_id::text from public.profiles where id = auth.uid())
-- );
-- create policy "Authenticated users can read documents from their organization folder"
-- on storage.objects for select to authenticated using (
--   bucket_id = 'crm-documents' AND (storage.foldername(name))[1] = (select organization_id::text from public.profiles where id = auth.uid())
-- );
