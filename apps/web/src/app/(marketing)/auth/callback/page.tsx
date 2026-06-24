import { AuthCallbackClient } from "@/components/auth/AuthCallbackClient";

export const metadata = {
  title: "Signing in",
  robots: { index: false, follow: false },
};

export default function AuthCallbackPage() {
  return <AuthCallbackClient />;
}
