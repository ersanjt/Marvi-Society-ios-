/**
 * Shared with iOS: Core/DesignSystem/Theme/Colors.swift & Gradients.swift
 * Keep web tokens in sync when the app palette changes.
 */
export const MARVI_BRAND = {
  colors: {
    ink: "#F5F5F7",
    graphite: "#C8C8CC",
    surface: "#0A0A0C",
    surfaceCool: "#121216",
    panel: "#1C1C1E",
    panelElevated: "#242428",
    emerald: "#34D399",
    aubergine: "#8B5CF6",
    gold: "#F5C542",
    rose: "#FF2D78",
    tomato: "#FF6B6B",
    blue: "#60A5FA",
    muted: "#8E8E93",
    border: "rgba(255, 255, 255, 0.08)",
  },
  gradient: {
    brand: "linear-gradient(90deg, #FF2D78 0%, #8B5CF6 100%)",
    brandVertical:
      "linear-gradient(135deg, #FF2D78 0%, #8B5CF6 50%, #4C1D95 100%)",
    warm:
      "linear-gradient(135deg, rgba(255,45,120,0.35) 0%, rgba(139,92,246,0.25) 50%, #0A0A0C 100%)",
  },
  radius: {
    mark: "12px",
    card: "16px",
    pill: "9999px",
  },
} as const;
