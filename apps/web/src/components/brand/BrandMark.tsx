import { MARVI_BRAND } from "@/config/brand";

type BrandMarkProps = {
  size?: number;
  className?: string;
};

/** Matches iOS `BrandMark` — gradient tile + serif M */
export function BrandMark({ size = 40, className = "" }: BrandMarkProps) {
  return (
    <div
      className={`flex shrink-0 items-center justify-center bg-gradient-to-r from-rose to-aubergine font-serif font-bold text-white shadow-lg shadow-rose/25 ring-1 ring-inset ring-white/20 ${className}`}
      style={{
        width: size,
        height: size,
        borderRadius: MARVI_BRAND.radius.mark,
        fontSize: Math.round(size * 0.48),
      }}
      aria-label="Marvi Society"
      role="img"
    >
      M
    </div>
  );
}

type BrandLockupProps = {
  subtitle?: string;
  size?: number;
  className?: string;
};

/** Matches iOS `BrandLockup` */
export function BrandLockup({ subtitle, size = 48, className = "" }: BrandLockupProps) {
  return (
    <div className={`flex items-center gap-3 ${className}`}>
      <BrandMark size={size} />
      <div className="min-w-0">
        <p className="truncate font-serif text-lg font-bold leading-tight text-ink">Marvi Society</p>
        {subtitle ? (
          <p className="truncate text-[10px] font-bold uppercase tracking-[0.14em] text-muted">
            {subtitle}
          </p>
        ) : null}
      </div>
    </div>
  );
}
