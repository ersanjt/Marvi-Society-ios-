import { PortalNav } from "@/components/portal/PortalNav";
import { VenueSwitcher } from "@/components/portal/VenueSwitcher";

export default function PortalLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-[70vh] bg-surface-cool">
      <PortalNav />
      <VenueSwitcher />
      {children}
    </div>
  );
}
