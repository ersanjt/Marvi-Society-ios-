INSERT INTO public.notifications (user_id, title, body, type, icon, tint, payload)
SELECT DISTINCT ON (vp.owner_user_id)
    vp.owner_user_id,
    CASE WHEN coalesce(p.preferred_locale, 'en') = 'tr' THEN 'Mekânın onaylandı' ELSE 'Venue approved' END,
    CASE WHEN coalesce(p.preferred_locale, 'en') = 'tr'
        THEN coalesce(nullif(vp.venue_name, ''), 'Mekânın') || ' onaylandı. Stüdyo’dan kampanya oluşturabilirsin.'
        ELSE coalesce(nullif(vp.venue_name, ''), 'Your venue') || ' was approved. You can create campaigns in Studio.'
    END,
    'membership',
    'checkmark.seal.fill',
    'emerald',
    jsonb_build_object('deep_link', 'marvisociety://studio', 'venue_id', vp.id)
FROM public.venue_profiles vp
JOIN public.profiles p ON p.id = vp.owner_user_id
WHERE vp.status = 'approved'
  AND NOT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.user_id = vp.owner_user_id
        AND n.type = 'membership'
        AND (
          n.title ILIKE '%onaylandı%'
          OR n.title ILIKE '%approved%'
          OR n.title ILIKE '%Venue approved%'
          OR n.title ILIKE '%Mekânın onaylandı%'
        )
  )
ORDER BY vp.owner_user_id, vp.updated_at DESC NULLS LAST, vp.created_at DESC;
