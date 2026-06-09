-- Demo requests, referrals, storage buckets

CREATE TABLE public.demo_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    company TEXT NOT NULL,
    email TEXT NOT NULL,
    website TEXT,
    message TEXT,
    source TEXT DEFAULT 'web',
    status TEXT DEFAULT 'new',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.demo_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY demo_requests_insert_public ON public.demo_requests
    FOR INSERT WITH CHECK (true);

CREATE POLICY demo_requests_admin_read ON public.demo_requests
    FOR SELECT USING (public.is_admin());

CREATE TABLE public.referral_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    owner_user_id UUID REFERENCES public.profiles (id) ON DELETE SET NULL,
    owner_type TEXT NOT NULL DEFAULT 'creator',
    uses_count INTEGER NOT NULL DEFAULT 0,
    max_uses INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.referral_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY referral_read ON public.referral_codes
    FOR SELECT USING (true);

CREATE POLICY referral_admin ON public.referral_codes
    FOR ALL USING (public.is_admin());

-- Storage buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES
    ('proof-uploads', 'proof-uploads', false, 10485760),
    ('venue-media', 'venue-media', true, 5242880)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY proof_upload_own ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'proof-uploads'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

CREATE POLICY proof_read_own ON storage.objects
    FOR SELECT USING (
        bucket_id = 'proof-uploads'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

CREATE POLICY venue_media_public_read ON storage.objects
    FOR SELECT USING (bucket_id = 'venue-media');

CREATE POLICY venue_media_upload ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'venue-media'
        AND auth.role() = 'authenticated'
    );

-- Account deletion request log
CREATE TABLE public.deletion_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    otp_hash TEXT,
    expires_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.deletion_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY deletion_insert ON public.deletion_requests
    FOR INSERT WITH CHECK (true);
