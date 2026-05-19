# Brand Tokens

Catalog-backed color tokens for the Mochi iOS and watchOS apps. These ship in
both `Mochi/Assets.xcassets/` and `Mochi Watch App/Assets.xcassets/`, with
matching light and dark appearance entries in each `.colorset`.

## Tokens

| Token          | Light hex | Dark hex  | Intended usage                                                |
| -------------- | --------- | --------- | ------------------------------------------------------------- |
| `BrandPrimary` | `#FF9F7A` | `#E08560` | Launch screen background, AppIcon background, primary surface accents. Warm peach matching Mochi's pet aesthetic. |
| `BrandAccent`  | `#6E9AB8` | `#8FB6D0` | Highlights, secondary buttons, focus rings, complement to BrandPrimary. |
| `CalmGreen`    | `#57D1A3` | `#3FA880` | Catalog-backed equivalent to inline `Color.calm`. Use for chart "calm minutes" fills and brand surfaces that need the calm hue. |
| `OverOrange`   | `#F3625D` | `#D04C48` | Catalog-backed equivalent to inline `Color.over`. Use for chart "over minutes" fills and over-stress brand surfaces. |

## Swift surface

Each target gets a convenience extension (added by Apollo in a later step):

```swift
extension Color {
    static let brandPrimary = Color("BrandPrimary")
    static let brandAccent  = Color("BrandAccent")
    static let calmGreen    = Color("CalmGreen")
    static let overOrange   = Color("OverOrange")
}
```

These resolve via the asset catalog, so dark-mode swaps happen automatically.

## Mapping: inline vs catalog

`Mochi Watch App/Theme/Palette.swift` defines `Color.calm` and `Color.over` as
raw RGB constants used inline in `BreathView` and `SummaryView`. `CalmGreen`
and `OverOrange` are the catalog-backed equivalents — same role, but resolved
through the asset catalog so they pick up dark-appearance variants and can be
referenced from Interface Builder, launch screens, and other non-Swift
surfaces. The inline constants remain stable for back-compat; prefer the
catalog tokens for any new brand-facing surface (chart fills, icon and launch
backgrounds, marketing screens).
