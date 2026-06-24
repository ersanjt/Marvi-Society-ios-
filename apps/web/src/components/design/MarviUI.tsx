import type { ReactNode } from "react";
import type { StatusTone } from "@/lib/operational/status";

export type { StatusTone };

const TONE_TEXT: Record<StatusTone, string> = {
  rose: "text-rose",
  emerald: "text-emerald",
  gold: "text-gold",
  tomato: "text-tomato",
  aubergine: "text-aubergine",
  blue: "text-blue",
  muted: "text-muted",
};

const TONE_CLASS: Record<StatusTone, string> = {
  rose: "bg-rose/15 text-rose",
  emerald: "bg-emerald/15 text-emerald",
  gold: "bg-gold/15 text-gold",
  tomato: "bg-tomato/15 text-tomato",
  aubergine: "bg-aubergine/15 text-aubergine",
  blue: "bg-blue/15 text-blue",
  muted: "bg-panel-elevated text-muted",
};

export function MarviScreen({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <div className={`relative overflow-hidden ${className}`}>
      <div
        className="pointer-events-none absolute -top-20 left-1/2 h-[280px] w-[min(100%,720px)] -translate-x-1/2 rounded-full bg-brand-gradient-vertical opacity-35 blur-[80px]"
        aria-hidden
      />
      <div className="relative">{children}</div>
    </div>
  );
}

export function StatusPill({ label, tone = "rose" }: { label: string; tone?: StatusTone }) {
  return (
    <span className={`marvi-pill ${TONE_CLASS[tone]}`}>
      {label}
    </span>
  );
}

export function MetricTile({
  icon,
  value,
  label,
  hint,
  tone = "rose",
}: {
  icon: ReactNode;
  value: string;
  label: string;
  hint?: string;
  tone?: StatusTone;
}) {
  return (
    <div className="marvi-card flex flex-col gap-3 p-4">
      <div className={`flex h-10 w-10 items-center justify-center rounded-marvi ${TONE_CLASS[tone]}`}>
        {icon}
      </div>
      <div>
        <p className="bg-brand-gradient bg-clip-text text-2xl font-bold text-transparent">{value}</p>
        <p className="text-sm font-bold text-ink">{label}</p>
        {hint ? <p className="text-xs text-muted">{hint}</p> : null}
      </div>
    </div>
  );
}

export function FilterPill({
  label,
  active = false,
  onClick,
}: {
  label: string;
  active?: boolean;
  onClick?: () => void;
}) {
  const Tag = onClick ? "button" : "span";
  return (
    <Tag
      type={onClick ? "button" : undefined}
      onClick={onClick}
      className={
        active
          ? "marvi-pill bg-brand-gradient text-white shadow-rose"
          : "marvi-pill border border-border bg-panel text-graphite"
      }
    >
      {label}
    </Tag>
  );
}

export function EmptyState({
  icon,
  title,
  body,
  action,
}: {
  icon: ReactNode;
  title: string;
  body: string;
  action?: ReactNode;
}) {
  return (
    <div className="marvi-card flex flex-col items-center px-6 py-14 text-center">
      <div className="flex h-14 w-14 items-center justify-center rounded-marvi-lg bg-panel-elevated text-rose">
        {icon}
      </div>
      <h3 className="mt-5 font-serif text-xl font-bold text-ink">{title}</h3>
      <p className="mt-2 max-w-sm text-sm text-muted">{body}</p>
      {action ? <div className="mt-6">{action}</div> : null}
    </div>
  );
}

export function GradientCTA({
  children,
  className = "",
  href,
}: {
  children: ReactNode;
  className?: string;
  href?: string;
}) {
  const classes = `inline-flex items-center justify-center gap-2 rounded-marvi bg-brand-gradient px-6 py-3.5 text-xs font-bold uppercase tracking-[0.14em] text-white shadow-rose transition hover:opacity-90 ${className}`;
  if (href) {
    return (
      <a href={href} className={classes}>
        {children}
      </a>
    );
  }
  return <span className={classes}>{children}</span>;
}

export function PageHeader({
  eyebrow,
  title,
  subtitle,
  action,
}: {
  eyebrow: string;
  title: string;
  subtitle?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-wrap items-start justify-between gap-4">
      <div>
        <p className="marvi-eyebrow">{eyebrow}</p>
        <h1 className="font-serif text-3xl font-bold text-ink md:text-4xl">{title}</h1>
        {subtitle ? <p className="mt-2 max-w-2xl text-sm text-muted">{subtitle}</p> : null}
      </div>
      {action ? <div className="shrink-0">{action}</div> : null}
    </div>
  );
}

export function ListRow({
  title,
  subtitle,
  meta,
  badge,
  trailing,
}: {
  title: string;
  subtitle?: string;
  meta?: string;
  badge?: ReactNode;
  trailing?: ReactNode;
}) {
  return (
    <div className="flex items-start justify-between gap-4 rounded-marvi border border-border bg-panel-elevated/60 px-4 py-3">
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-2">
          <p className="truncate font-semibold text-ink">{title}</p>
          {badge}
        </div>
        {subtitle ? <p className="mt-0.5 truncate text-sm text-muted">{subtitle}</p> : null}
        {meta ? <p className="mt-1 text-xs text-muted">{meta}</p> : null}
      </div>
      {trailing ? <div className="shrink-0">{trailing}</div> : null}
    </div>
  );
}

export function StudioStatusGrid({
  items,
}: {
  items: Array<{ label: string; value: string; tone?: StatusTone }>;
}) {
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
      {items.map((item) => (
        <div key={item.label} className="marvi-card p-4">
          <p className={`text-2xl font-bold ${item.tone ? TONE_TEXT[item.tone] : "text-ink"}`}>
            {item.value}
          </p>
          <p className="mt-1 text-xs font-bold uppercase tracking-wide text-muted">{item.label}</p>
        </div>
      ))}
    </div>
  );
}

export function SyncBanner({
  tone,
  message,
  action,
}: {
  tone: "error" | "success" | "info";
  message: string;
  action?: ReactNode;
}) {
  const styles =
    tone === "error"
      ? "border-tomato/30 bg-tomato/10 text-tomato"
      : tone === "success"
        ? "border-emerald/30 bg-emerald/10 text-emerald"
        : "border-blue/30 bg-blue/10 text-blue";

  return (
    <div className={`flex flex-wrap items-center justify-between gap-3 rounded-marvi border px-4 py-3 text-sm ${styles}`}>
      <span>{message}</span>
      {action}
    </div>
  );
}

export function SkeletonBlock({ className = "" }: { className?: string }) {
  return <div className={`animate-pulse rounded-marvi bg-panel-elevated ${className}`} aria-hidden />;
}

export function AvatarRing({
  initials,
  size = 64,
}: {
  initials: string;
  size?: number;
}) {
  return (
    <div
      className="flex items-center justify-center rounded-full bg-brand-gradient p-[2px] font-bold text-white shadow-rose"
      style={{ width: size, height: size }}
    >
      <div
        className="flex h-full w-full items-center justify-center rounded-full bg-panel text-sm font-bold text-ink"
        style={{ fontSize: size * 0.28 }}
      >
        {initials.slice(0, 2).toUpperCase()}
      </div>
    </div>
  );
}

export function SegmentedTabs({
  tabs,
  active,
  onChange,
}: {
  tabs: Array<{ id: string; label: string }>;
  active: string;
  onChange: (id: string) => void;
}) {
  return (
    <div className="flex flex-wrap gap-2 rounded-marvi-lg border border-border bg-panel p-1">
      {tabs.map((tab) => (
        <button
          key={tab.id}
          type="button"
          onClick={() => onChange(tab.id)}
          className={
            active === tab.id
              ? "marvi-pill flex-1 bg-brand-gradient text-white shadow-rose sm:flex-none"
              : "marvi-pill flex-1 text-graphite sm:flex-none"
          }
        >
          {tab.label}
        </button>
      ))}
    </div>
  );
}
