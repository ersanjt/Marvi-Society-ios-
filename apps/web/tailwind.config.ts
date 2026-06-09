import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        ink: "#15171A",
        graphite: "#2C3036",
        muted: "#6B7280",
        surface: "#F4F1EA",
        cool: "#EEF3F4",
        panel: "#FFFFFF",
        emerald: "#0E7C66",
        aubergine: "#5C315E",
        gold: "#C69A32",
        rose: "#B85C7A",
        tomato: "#D25D3D",
        blue: "#316D9E",
      },
      fontFamily: {
        serif: ["Georgia", "Times New Roman", "serif"],
      },
      borderRadius: {
        marvi: "8px",
      },
    },
  },
  plugins: [],
};

export default config;
