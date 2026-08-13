/**
 * Shared with iOS: Core/DesignSystem/Theme/Colors.swift & Gradients.swift
 * Keep web tokens in sync when the app palette changes.
 */
export const MARVI_BRAND = {
  colors: {
    ink: "#F5F5F7",
    graphite: "#C8C8CC",
    surface: "#000000",
    surfaceCool: "#07070A",
    panel: "#121214",
    panelElevated: "#1A1A1E",
    /** Success / confirmed only. */
    emerald: "#34D399",
    aubergine: "#8B5CF6",
    /** Highlight — brand-aligned (not literal gold). Prefer rose in new UI. */
    gold: "#FF2D78",
    rose: "#FF2D78",
    /** Error / destructive only. */
    tomato: "#FF6B6B",
    /** Info — brand-aligned (not sky blue). Prefer aubergine in new UI. */
    blue: "#8B5CF6",
    muted: "#8E8E93",
    border: "rgba(255, 255, 255, 0.08)",
  },
  gradient: {
    brand: "linear-gradient(90deg, #FF2D78 0%, #8B5CF6 100%)",
    brandVertical:
      "linear-gradient(135deg, #FF2D78 0%, #8B5CF6 50%, #4C1D95 100%)",
    warm:
      "linear-gradient(135deg, rgba(255,45,120,0.35) 0%, rgba(139,92,246,0.25) 50%, #000000 100%)",
  },
  radius: {
    mark: "12px",
    card: "16px",
    pill: "9999px",
  },
} as const;
