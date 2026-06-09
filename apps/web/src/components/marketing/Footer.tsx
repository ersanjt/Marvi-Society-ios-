import Link from "next/link";
import { SITE } from "@/lib/constants";

export function Footer() {
  return (
    <footer className="border-t border-black/5 bg-ink text-white">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-14 md:grid-cols-4 md:px-6">
        <div className="md:col-span-2">
          <p className="font-serif text-2xl font-bold">{SITE.name}</p>
          <p className="mt-3 max-w-md text-sm text-white/70">{SITE.tagline}</p>
        </div>

        <div>
          <p className="text-xs font-bold uppercase tracking-wider text-gold">Product</p>
          <ul className="mt-4 space-y-2 text-sm text-white/80">
            <li><Link href="/creators" className="hover:text-white">Creators</Link></li>
            <li><Link href="/brands" className="hover:text-white">Brands</Link></li>
            <li><Link href="/faq" className="hover:text-white">FAQ</Link></li>
            <li><Link href="/demo" className="hover:text-white">Demo</Link></li>
          </ul>
        </div>

        <div>
          <p className="text-xs font-bold uppercase tracking-wider text-gold">Legal</p>
          <ul className="mt-4 space-y-2 text-sm text-white/80">
            <li><Link href="/privacy" className="hover:text-white">Privacy</Link></li>
            <li><Link href="/terms" className="hover:text-white">Terms</Link></li>
            <li><Link href="/contact" className="hover:text-white">Contact</Link></li>
            <li><Link href="/delete-account" className="hover:text-white">Delete account</Link></li>
          </ul>
        </div>
      </div>

      <div className="border-t border-white/10 px-4 py-6 text-center text-xs text-white/50 md:px-6">
        © {new Date().getFullYear()} {SITE.name}. All rights reserved.
      </div>
    </footer>
  );
}
