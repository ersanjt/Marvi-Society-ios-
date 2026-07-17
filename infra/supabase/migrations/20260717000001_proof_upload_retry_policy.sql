-- Allow creators to replace a proof screenshot for the same booking.
-- The clients upload with x-upsert=true, which becomes UPDATE when the
-- deterministic object path already exists.

DROP POLICY IF EXISTS proof_update_own ON storage.objects;
CREATE POLICY proof_update_own ON storage.objects
    FOR UPDATE
    USING (
        bucket_id = 'proof-uploads'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    )
    WITH CHECK (
        bucket_id = 'proof-uploads'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );
