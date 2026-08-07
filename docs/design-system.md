# The design system

**Files:** `AppStarter/DesignSystem/Theme.swift`, `Components.swift`

---

## Rebranding the app

Open `Theme.swift` and change two lines:

```swift
static let accent = Color(light: 0x3B82F6, dark: 0x3B82F6)
static let onAccent = Color(light: 0xFFFFFF, dark: 0xFFFFFF)
```

That's the whole job. Buttons, the tab bar, selected states, onboarding, the paywall checkmarks. Everything reads from `Theme`, and nothing hardcodes a color anywhere else.

`onAccent` is what gets drawn **on top of** the accent. Set it to whatever stays readable: white on a mid-blue, near-black on a yellow or lime. Getting this wrong is the usual cause of an unreadable primary button after a rebrand.

### Roundness

```swift
static let cornerRadius: CGFloat = 14
```

One value drives every card and button. `4` reads sharp and technical; `20` reads soft and consumer. It's the fastest way to change the app's character without touching a single view.

---

## Why code and not an asset catalog

Both work, and asset catalogs are the conventional answer. This starter uses code because:

- **It's greppable and diffable.** A color change is a one-line PR, not an opaque `Contents.json` blob.
- **Both appearances sit on one line.** `Color(light:dark:)` puts the pair next to each other, where a bad contrast pairing is obvious at a glance. In a catalog they're two rows in a UI you have to click into.
- **It travels.** Copy `Theme.swift` into another project; no asset folders to drag.

If you'd rather use the catalog, replace the property bodies with `Color("Accent")` and keep the names. Nothing else in the app changes, that's the point of routing everything through one type.

---

## `Color(light:dark:)`

```swift
init(light: UInt32, dark: UInt32) {
    self.init(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: dark): UIColor(hex: light)
    })
}
```

The dynamic `UIColor` provider is doing real work here. It resolves at **draw** time against whatever trait collection the view is in.

The alternative, picking a color with an `if` on `@Environment(\.colorScheme)`, resolves at **render** time, so it only updates when the body re-runs. That's why apps end up with one stubborn view that stays light after the system flips to dark: its body didn't happen to re-evaluate. The dynamic provider has no such failure mode.

`UIColor(hex:)` deliberately takes no alpha. A design system with transparency baked into its tokens composites unpredictably over different surfaces; use `.opacity()` at the call site, where you can see what's behind it.

---

## Appearance preference

`AppSettings.appearance` is `.light`, `.dark` or `.system`, persisted in `UserDefaults`, and applied once at the root:

```swift
RootView().preferredColorScheme(settings.appearance.colorScheme)
```

**`.system` is a real third option, not the absence of a choice.** A user who never touches the setting should keep following their device as it changes at sunset; a user who explicitly picked Dark should stay dark at noon. Collapsing this to a boolean is the usual reason an app's dark mode "randomly turns itself back on".

Applying it at the root also means sheets and `fullScreenCover`s inherit it. Scatter `.preferredColorScheme` per screen and you eventually get a light-mode modal over a dark app, which looks broken.

---

## Components

`Components.swift` holds the shared pieces:

| | |
|---|---|
| `Card` | Rounded container on `Theme.surface`. The default grouping. |
| `PrimaryButtonStyle` | Filled action. One per screen, two primaries means neither is. |
| `SecondaryButtonStyle` | Sits on a surface, doesn't compete. |
| `SectionLabel` | Small uppercase group header, the iOS Settings idiom. |
| `InfoRow` / `NavigationRow` | Label-value and tappable rows. |
| `StatusRow` | Dot + value. Used by the Growth screen. |
| `ScreenScrollView` | Large title + gutters + background. Every tab uses it. |

**Keep this file small.** A design system earns its keep when there are five pieces everyone uses. At fifty, people start writing bespoke views anyway, because finding the right component costs more than rewriting it.

### Hit targets

`NavigationRow` applies `.contentShape(Rectangle())`. Without it, only the *text* is tappable: the empty space between the label and the chevron isn't, which users experience as "the app ignored my tap". Any row where the tappable area is larger than its visible content needs this.

---

## Dynamic Type

`.layoutSafeDynamicType()` caps text scaling at `.accessibility3`.

iOS accessibility sizes go to roughly 310%. Uncapped, a row-based layout at that size doesn't degrade gracefully, buttons overflow, labels collide, tab titles overlap. The cap keeps text meaningfully larger for people who need it while keeping the layout intact.

Apply it to **chrome**: tab bars, compact rows, badges. Leave **body copy** uncapped so reading content scales as far as the user asked.

Never reach for `.dynamicTypeSize(.large)` as a flat cap. That's the version that ignores the user's setting outright, and it's the accessibility bug people actually notice and write reviews about.

---

## Adding a second brand theme

The simplest approach that scales: make `Theme` a struct with static instances rather than an enum of statics.

```swift
struct Palette {
    let accent: Color
    let background: Color
    // …
}

extension Palette {
    static let blue = Palette(accent: Color(light: 0x3B82F6, dark: 0x3B82F6), …)
    static let ocean = Palette(accent: Color(light: 0x0891B2, dark: 0x22D3EE), …)
}
```

Put the active palette in the environment and read it with `@Environment(\.palette)`. Worth doing when you genuinely ship multiple brands or let users pick a theme; overkill before that, which is why the starter doesn't.

---

## Fonts

Add a font file to the target, list it under `UIAppFonts` in `Info.plist`, then use it in one place:

```swift
extension Font {
    static func app(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(weightName(weight), size: size)
    }
}
```

Then replace `.font(.system(size: 16))` with `.font(.app(16))` across the views. Doing it through one helper is what lets you swap the typeface later without touching every file: the same argument as `Theme` for colors.
