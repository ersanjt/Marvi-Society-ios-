"use client";

import { usePathname } from "next/navigation";
import type { ReactNode } from "react";

export function PortalChrome({
  children,
  chrome,
}: {
  children: ReactNode;
  chrome: ReactNode;
}) {
  const pathname = usePathname();
  const isLogin = pathname === "/portal/login";

  if (isLogin) {
    return <div className="min-h-screen bg-surface">{children}</div>;
  }

  return (
    <div className="min-h-[70vh] bg-surface-cool">
      {chrome}
      {children}
    </div>
  );
}
