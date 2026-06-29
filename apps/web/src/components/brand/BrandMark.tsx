import Image from "next/image";

type BrandMarkProps = {
  size?: number;
  className?: string;
};

/** Matches iOS `BrandMark` — uses the app-icon artwork */
export function BrandMark({ size = 40, className = "" }: BrandMarkProps) {
  return (
    <Image
      src="/brand-mark.png"
      alt="Marvi Society"
      width={size}
      height={size}
      priority
      className={`shrink-0 object-cover ${className}`}
      style={{
        width: size,
        height: size,
        borderRadius: Math.round(size * 0.2237),
      }}
    />
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
