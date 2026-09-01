# Marvi Society Design System

Live tokens match the shipping OLED apps, not the older cream/emerald mock.

Source of truth:

- Web: `apps/web/src/config/brand.ts`
- iOS: `apps/ios/MarviSociety/Core/DesignSystem/Theme/Colors.swift`

## Product feel

Private, operational, premium. Dark club lighting: near-black surfaces, rose-to-violet brand gradient, serif only for brand moments.

## Visual direction

- OLED black base (`#000000`), not cream paper
- 16px card radius, 12px mark, pill 9999
- Rose `#FF2D78` is the primary accent (CTA, featured, brand start)
- Violet `#8B5CF6` is the secondary accent (brand end, info)
- Emerald and tomato are reserved for success and error
- No decorative blob backgrounds
- Cards for discrete tools, offers, tasks, and records

## Core colors

| Token | Hex | Use |
|-------|-----|-----|
| Ink | `#F5F5F7` | Primary text on dark |
| Graphite | `#C8C8CC` | Secondary text |
| Muted | `#8E8E93` | Captions |
| Surface | `#000000` | Screen background |
| Surface cool | `#07070A` | Alternate base |
| Panel | `#121214` | Cards / sheets |
| Panel elevated | `#1A1A1E` | Nested surfaces |
| Border | `rgba(255,255,255,0.08)` | Hairline |
| Rose | `#FF2D78` | Brand / CTA / featured |
| Aubergine | `#8B5CF6` | Brand end / info |
| Gold | `#FF2D78` | Alias of rose (legacy name) |
| Blue | `#8B5CF6` | Alias of aubergine (legacy name) |
| Emerald | `#34D399` | Success / confirmed only |
| Tomato | `#FF6B6B` | Error / destructive only |

## Gradient

- Horizontal brand: `#FF2D78` → `#8B5CF6`
- Vertical brand: `#FF2D78` → `#8B5CF6` → `#4C1D95`

## Components

- `MarviScreen`: OLED background + faint brand wash
- `BrandMark` / `BrandLockup`: identity
- `MarviCard`: `panel` fill, 16px radius
- `StatusPill`: compact state label
- `InfoBadge`: date, time, capacity, priority
- `MetricTile`: dashboard metric — live counts only, never invented reach
- `PrimaryActionButton`: rose fill
- `SecondaryActionButton`: panel + border

## Product surfaces

- Onboarding (18+ confirmation stored as `age_confirmed_at`)
- Discover (paid Featured carousel from `featured_until`)
- Offer detail, bookings, proof
- Inbox
- Profile (in-app safety report)
- Venue Studio + Boost CTA to web billing
- Admin queue, leads, safety
- Web marketing `/pricing`, `/cookies`, portal `/portal/billing`
