-- Paste in Supabase SQL Editor if CLI is not linked.
-- Fixes profile photo replace/upload failures (own + admin).

DROP POLICY IF EXISTS profile_media_update_own ON storage.objects;
CREATE POLICY profile_media_update_own ON storage.objects
    FOR UPDATE
    USING (
        bucket_id = 'profile-media'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    )
    WITH CHECK (
        bucket_id = 'profile-media'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS profile_media_upload_own ON storage.objects;
CREATE POLICY profile_media_upload_own ON storage.objects
    FOR INSERT
    WITH CHECK (
        bucket_id = 'profile-media'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS profile_media_delete_own ON storage.objects;
CREATE POLICY profile_media_delete_own ON storage.objects
    FOR DELETE
    USING (
        bucket_id = 'profile-media'
        AND auth.uid()::TEXT = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS profile_media_public_read ON storage.objects;
CREATE POLICY profile_media_public_read ON storage.objects
    FOR SELECT
    USING (bucket_id = 'profile-media');

DROP POLICY IF EXISTS profile_media_admin_write ON storage.objects;
CREATE POLICY profile_media_admin_write ON storage.objects
    FOR ALL
    USING (bucket_id = 'profile-media' AND public.is_admin())
    WITH CHECK (bucket_id = 'profile-media' AND public.is_admin());
