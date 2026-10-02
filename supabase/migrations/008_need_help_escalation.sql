-- 008_need_help_escalation.sql
-- Implement Need Help / Escalation Management Module

-- 1. Create help_requests table
CREATE TABLE IF NOT EXISTS public.help_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    contact_person_id UUID REFERENCES public.contact_persons(id) ON DELETE SET NULL,
    interaction_id UUID REFERENCES public.interactions(id) ON DELETE SET NULL,
    followup_id UUID REFERENCES public.followups(id) ON DELETE SET NULL,
    document_id UUID REFERENCES public.documents(id) ON DELETE SET NULL,

    requested_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    assigned_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL,

    help_type TEXT NOT NULL DEFAULT 'General Support',
    title TEXT NOT NULL,
    description TEXT,
    priority TEXT DEFAULT 'medium',
    status TEXT DEFAULT 'open',

    resolution_note TEXT,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,

    created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    updated_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create help_request_comments table
CREATE TABLE IF NOT EXISTS public.help_request_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    help_request_id UUID NOT NULL REFERENCES public.help_requests(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    comment TEXT NOT NULL,
    is_internal BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Enable RLS
ALTER TABLE public.help_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.help_request_comments ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS Policies for help_requests
DROP POLICY IF EXISTS "Users can view help_requests from their organization" ON public.help_requests;
CREATE POLICY "Users can view help_requests from their organization"
    ON public.help_requests FOR SELECT
    USING (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can create help_requests for their organization" ON public.help_requests;
CREATE POLICY "Users can create help_requests for their organization"
    ON public.help_requests FOR INSERT
    WITH CHECK (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can update help_requests from their organization" ON public.help_requests;
CREATE POLICY "Users can update help_requests from their organization"
    ON public.help_requests FOR UPDATE
    USING (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can delete help_requests from their organization" ON public.help_requests;
CREATE POLICY "Users can delete help_requests from their organization"
    ON public.help_requests FOR DELETE
    USING (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

-- 5. Create RLS Policies for help_request_comments
DROP POLICY IF EXISTS "Users can view help_request_comments from their organization" ON public.help_request_comments;
CREATE POLICY "Users can view help_request_comments from their organization"
    ON public.help_request_comments FOR SELECT
    USING (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can insert help_request_comments for their organization" ON public.help_request_comments;
CREATE POLICY "Users can insert help_request_comments for their organization"
    ON public.help_request_comments FOR INSERT
    WITH CHECK (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can update help_request_comments from their organization" ON public.help_request_comments;
CREATE POLICY "Users can update help_request_comments from their organization"
    ON public.help_request_comments FOR UPDATE
    USING (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can delete help_request_comments from their organization" ON public.help_request_comments;
CREATE POLICY "Users can delete help_request_comments from their organization"
    ON public.help_request_comments FOR DELETE
    USING (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

-- 6. Add updated_at trigger for help_requests
DROP TRIGGER IF EXISTS update_help_requests_updated_at ON public.help_requests;
CREATE TRIGGER update_help_requests_updated_at
    BEFORE UPDATE ON public.help_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_updated_by();

-- 7. Add updated_at trigger for help_request_comments
DROP TRIGGER IF EXISTS update_help_request_comments_updated_at ON public.help_request_comments;
CREATE TRIGGER update_help_request_comments_updated_at
    BEFORE UPDATE ON public.help_request_comments
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_updated_by();

-- 8. Add validation function for help_request relations
CREATE OR REPLACE FUNCTION public.validate_help_request_relations()
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

    -- Validate document belongs to same company and organization
    IF NEW.document_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.documents WHERE id = NEW.document_id AND company_id = NEW.company_id AND organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION 'Document must belong to the same company and organization';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS validate_help_request_relations_trigger ON public.help_requests;
CREATE TRIGGER validate_help_request_relations_trigger
    BEFORE INSERT OR UPDATE ON public.help_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_help_request_relations();
