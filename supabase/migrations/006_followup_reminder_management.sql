-- 006_followup_reminder_management.sql
-- Implement Follow-up & Reminder Management Module

-- 1. Create followups table
CREATE TABLE IF NOT EXISTS public.followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    contact_person_id UUID REFERENCES public.contact_persons(id) ON DELETE SET NULL,
    interaction_id UUID REFERENCES public.interactions(id) ON DELETE SET NULL,
    assigned_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    followup_type TEXT NOT NULL DEFAULT 'Phone Call',
    title TEXT NOT NULL,
    description TEXT,
    scheduled_at TIMESTAMPTZ NOT NULL,
    reminder_before_minutes INT DEFAULT 60,
    status TEXT NOT NULL DEFAULT 'pending',
    priority TEXT NOT NULL DEFAULT 'medium',
    completed_at TIMESTAMPTZ,
    completed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    rescheduled_from TIMESTAMPTZ,
    cancelled_reason TEXT,
    created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    updated_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create email_reminder_logs table
CREATE TABLE IF NOT EXISTS public.email_reminder_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    followup_id UUID NOT NULL REFERENCES public.followups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    provider TEXT,
    error_message TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Enable RLS
ALTER TABLE public.followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_reminder_logs ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS Policies for followups
DROP POLICY IF EXISTS "Users can view followups from their organization" ON public.followups;
CREATE POLICY "Users can view followups from their organization"
    ON public.followups FOR SELECT
    USING (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can create followups for their organization" ON public.followups;
CREATE POLICY "Users can create followups for their organization"
    ON public.followups FOR INSERT
    WITH CHECK (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can update followups from their organization" ON public.followups;
CREATE POLICY "Users can update followups from their organization"
    ON public.followups FOR UPDATE
    USING (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can delete followups from their organization" ON public.followups;
CREATE POLICY "Users can delete followups from their organization"
    ON public.followups FOR DELETE
    USING (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

-- 5. Create RLS Policies for email_reminder_logs
DROP POLICY IF EXISTS "Users can view email_reminder_logs from their organization" ON public.email_reminder_logs;
CREATE POLICY "Users can view email_reminder_logs from their organization"
    ON public.email_reminder_logs FOR SELECT
    USING (organization_id = (SELECT organization_id FROM public.profiles WHERE id = auth.uid()));

-- 6. Add updated_at trigger for followups
DROP TRIGGER IF EXISTS update_followups_updated_at ON public.followups;
CREATE TRIGGER update_followups_updated_at
    BEFORE UPDATE ON public.followups
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_updated_by();

-- 7. Add validation function for company/contact/interaction ownership
CREATE OR REPLACE FUNCTION public.validate_followup_relations()
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

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS validate_followup_relations_trigger ON public.followups;
CREATE TRIGGER validate_followup_relations_trigger
    BEFORE INSERT OR UPDATE ON public.followups
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_followup_relations();
