"use client";

import { useEffect, useState } from "react";

const STORAGE_KEY = "marvi_cookie_consent";

export function CookieConsent() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (typeof window === "undefined") return;
    setVisible(!window.localStorage.getItem(STORAGE_KEY));
  }, []);

  if (!visible) return null;

  return (
    <div className="fixed inset-x-0 bottom-0 z-50 border-t border-black/10 bg-white/95 p-4 shadow-lg backdrop-blur">
      <div className="mx-auto flex max-w-5xl flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <p className="text-sm text-graphite">
          We use essential cookies for login and analytics to improve Marvi Society. See our{" "}
          <a href="/privacy" className="font-semibold text-emerald hover:underline">
            Privacy Policy
          </a>
          .
        </p>
        <div className="flex gap-2">
          <button
            type="button"
            className="marvi-btn-secondary"
            onClick={() => {
              window.localStorage.setItem(STORAGE_KEY, "essential");
              setVisible(false);
            }}
          >
            Essential only
          </button>
          <button
            type="button"
            className="marvi-btn-primary"
            onClick={() => {
              window.localStorage.setItem(STORAGE_KEY, "all");
              setVisible(false);
            }}
          >
            Accept all
          </button>
        </div>
      </div>
    </div>
  );
}
