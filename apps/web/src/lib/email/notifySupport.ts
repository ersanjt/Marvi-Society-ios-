import { createAdminClient } from "@/lib/supabase/admin";
import { SITE } from "@/config/site";

type SupportTemplate = "contact_form" | "demo_request";

export async function queueSupportEmail(
  template: SupportTemplate,
  variables: Record<string, string>,
  locale = "en"
): Promise<{ ok: boolean; outboxId?: string; error?: string }> {
  const admin = createAdminClient();
  if (!admin) {
    return { ok: false, error: "Email queue unavailable (service role not configured)." };
  }

  const { data, error } = await admin.rpc("queue_transactional_email", {
    p_user_id: null,
    p_to_email: SITE.supportEmail,
    p_template: template,
    p_locale: locale,
    p_variables: variables,
  });

  if (error) {
    return { ok: false, error: error.message };
  }

  return { ok: true, outboxId: data as string | undefined };
}
