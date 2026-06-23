import type { Config } from "tailwindcss";
import { MARVI_BRAND } from "./src/config/brand";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        ink: MARVI_BRAND.colors.ink,
        graphite: MARVI_BRAND.colors.graphite,
        muted: MARVI_BRAND.colors.muted,
        surface: MARVI_BRAND.colors.surface,
        "surface-cool": MARVI_BRAND.colors.surfaceCool,
        cool: MARVI_BRAND.colors.surfaceCool,
        panel: MARVI_BRAND.colors.panel,
        "panel-elevated": MARVI_BRAND.colors.panelElevated,
        emerald: MARVI_BRAND.colors.emerald,
        aubergine: MARVI_BRAND.colors.aubergine,
        gold: MARVI_BRAND.colors.gold,
        rose: MARVI_BRAND.colors.rose,
        tomato: MARVI_BRAND.colors.tomato,
        blue: MARVI_BRAND.colors.blue,
        border: "rgba(255, 255, 255, 0.08)",
      },
      fontFamily: {
        serif: ["Georgia", "Times New Roman", "serif"],
        sans: [
          "-apple-system",
          "BlinkMacSystemFont",
          "Segoe UI",
          "Roboto",
          "Helvetica Neue",
          "Arial",
          "sans-serif",
        ],
      },
      borderRadius: {
        marvi: MARVI_BRAND.radius.mark,
        "marvi-lg": MARVI_BRAND.radius.card,
      },
      boxShadow: {
        rose: "0 12px 40px rgba(255, 45, 120, 0.18)",
        panel: "0 1px 0 rgba(255, 255, 255, 0.06) inset",
      },
      backgroundImage: {
        "brand-gradient": "linear-gradient(90deg, #FF2D78 0%, #8B5CF6 100%)",
        "brand-gradient-vertical":
          "linear-gradient(135deg, #FF2D78 0%, #8B5CF6 50%, #4C1D95 100%)",
        "brand-warm":
          "linear-gradient(135deg, rgba(255,45,120,0.35) 0%, rgba(139,92,246,0.25) 50%, #0A0A0C 100%)",
      },
    },
  },
  plugins: [],
};

export default config;
