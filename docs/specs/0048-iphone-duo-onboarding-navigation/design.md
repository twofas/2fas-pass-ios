# 0048 — iPhone Duo: the onboarding's one navigation stack

Status: design, 2026-10-26. Branch `develop`.

## Intent

On iPhone Duo the system moves navigation-bar items into a vertical bar on the
hardware edge (the outer display, and the inner display in landscape). The
onboarding's "Back" and the Recovery Kit's gear stay in the top-left and
top-right corners instead, because they are not system bar items: the
onboarding draws its own bar. Spec 0048 makes the onboarding one system
navigation stack whose bar the system owns, while keeping two things the
onboarding was built around:

1. the progress shield stays in one place above every step and animates
   between steps instead of moving with the screens;
2. the steps keep their own slide transition (`SlideAnimator`: the whole
   old screen leaves left, the new one enters from the right).

## What the probes established (2026-10-26, Xcode 27.1, iOS 27.1 simulator)

A throwaway probe launched the app with a bare test stack that pushed a
second screen on its own. On the folded Duo:

| Hierarchy | Vertical bar |
| --- | --- |
| `UINavigationController` as the window's root | yes, back and right item |
| custom container (`placeChild`) → `UINavigationController` | yes |
| the same with `childForPreferredVerticalBarBehavior` forwarded | yes, no difference |
| `UIHostingController` → SwiftUI `NavigationStack` | back yes; `.primaryAction` stays horizontal |
| `UIHostingController` → `UIViewControllerRepresentable` → `UINavigationController` (today's `SlideNavigationStack`) | **no**, everything horizontal |
| custom container → `UINavigationController` → pushed `UIHostingController` with SwiftUI `.toolbar` items (`.topBarPinnedTrailing` and `.primaryAction`) | back yes; **both SwiftUI items stay horizontal** in a pill at the top |

So neither `RootViewController`, nor the nested stacks, nor the extra windows
are the cause, and a SwiftUI `.toolbar` item of a hosted screen never reaches
the vertical bar either, whatever its placement: only a `UIBarButtonItem` on
the hosting controller's `navigationItem` does. A navigation controller wrapped in a representable inside a
SwiftUI hierarchy is invisible to the vertical-bar machinery, like a
hand-made `UINavigationBar`. Apple's guidance says the same: use
`UINavigationController`/`NavigationStack` and let the system place the items
(Tech Talks 111461 "Prepare your app for iPhone Duo", 111462 "Raise the bar
with iPhone Duo"). The SDK has no API that puts a custom view into the
vertical bar; `UITraitCollection.verticalBarEdge` (iOS 27.1) only tells where
it would be.

## Goals

- On iPhone Duo, "Back" on every onboarding step, the gear on the Recovery
  Kit step and "Back" in the recovery flow sit in the system's vertical bar,
  and the content is inset for it, as in the system Settings app.
- On every other iPhone and on iPad the onboarding looks and moves as today:
  the shield fixed above the steps, the steps sliding, the welcome pages
  without a bar.
- iOS 18 (the deployment target) keeps working; the vertical bar is an
  iOS 27.1 behaviour the system applies on its own.

## Non-goals

- The rest of the app (Main, Settings, the Business hub, AutoFill) is not
  audited here. A later spec covers whatever else the Duo needs.
- The AutoFill extension's representable around a `UINavigationController`
  (`AutoFill/AutoFillPasswordsListView.swift`) is not touched; D1's rule is
  about new code and the onboarding.
- The Settings variant of the Recovery Kit screen (`VaultDecryptionKitRouter.buildView(kind: .settings)` under a `NavigationStack`) keeps its `.toolbar`; nothing changes there.
- `UISupportedInterfaceOrientations` stays as it is.

## Anti-goals

- No `toolbarVerticalBehavior(.disabled)` / `preferredVerticalBarBehavior`
  to force horizontal bars: the SDK reserves it for screens like a video
  player, and the status bar would flip axis when entering the onboarding.
- No hand-drawn bar laid out along `verticalBarEdge`: it would imitate the
  system without its spacing, overflow or future changes.
- No second navigation stack inside the onboarding: a nested
  `UINavigationController` or `NavigationStack` gets no vertical bar.

## Design decisions

### D1. One UIKit navigation controller owns the onboarding

`OnboardingFlowController.embedAsRoot` creates one `UINavigationController`
(a CommonUI subclass, `SlideNavigationController`, replacing
`SlideNavigationStack`), assigns it to the flow controller's
`navigationController`, and places it in `RootViewController` with
`placeChild`, as today's hosting controller is placed. Its root view
controller hosts `OnboardingPagesView`; every later screen (the steps, the
recovery flow) is a `UIHostingController` pushed onto it. The screens stay
SwiftUI VIPER modules; only the container changes. Nowhere in the app may a
navigation controller sit inside a `UIViewControllerRepresentable` again.

### D2. The transition is chosen per push

The navigation controller's delegate returns `SlideAnimator` for a screen
pushed as `.slidePush` and `nil` (the system transition) for a screen pushed
as `.push`. On pop it decides by the screen being popped, so a slide-pushed
screen slides back and a system-pushed one pops as usual. The welcome pages
→ first step transition is therefore the system's (the first step is pushed
with `.slidePush` only if the product wants the slide there; see the
builder's calls below), and the steps between themselves slide. The edge
swipe is disabled while a `.slidePush` screen is on top (today's hidden bar
disables it too, and `SlideAnimator` is not interactive) and enabled on a
`.push` screen, where the system transition is interactive as usual
(decision 2026-10-26, option (a) of the builder check).

### D3. The router pushes onto the UIKit stack through the environment

`Router` learns one more target beside the SwiftUI `NavigationStack` path:
an environment value (name left to the builder, e.g. `flowNavigation`)
carrying "push this view as `.push` or `.slidePush`" and "pop me". When the
value is present, `.push` and `.slidePush` both go to it — the `.push`
destinations of the recovery flow included — and the preference-based
`slideNavigationDestination` is removed. When a screen is popped by the
system (back button, swipe), the controller's `didShow` clears the routing
`destination` of the screen below, the same consistency `SlideNavigationStack`
keeps by hand today; `destination = nil` from a presenter pops. Screens hosted
in a sheet or a `NavigationStack` of their own do not see the value (the
router already clears `navigationPath` for sheets; the same applies here), so
a recovery sheet with its own `NavigationStack` keeps working. "Pop me" pops
to the screen whose `destination` was cleared, not merely the top one:
`VaultRecoverySelectPresenter`'s `onTryAgain` clears its `destination` while
two screens sit above it, and today's `NavigationStack` unwinds both.

### D4. The shield is an overlay of the stack, fed by a model

The progress shield (`ProgressView` with `ShieldProgressStyle`) is one SwiftUI
view hosted above the navigation controller's view (a passthrough overlay
added by `SlideNavigationController`), so it never moves with a screen. It
reads an `@Observable` `OnboardingProgress` model (`progress`, `isVisible`)
that the onboarding flow controller owns. The
`onboardingStepProgress(_:)` and `onboardingStepProgressVisibility(_:)`
modifiers keep their names, call sites and preference keys: a preference
still reaches the root of its own `UIHostingController`, and that is where a
wrapper the flow controller puts around every hosted screen reads it and
writes the model — on every change, and again each time the screen appears,
so a pop shows the revealed screen's values. A screen that claims nothing
(the welcome pages, the recovery flow) applies the defaults on appearance and
shows no shield. The progress animates as today
(`changeProgressAnimationDuration`, the ease-in-out of the visibility).
(Amended 2026-10-26 while planning: the preference keys stay; only the
reader moves from the stack to the host's root.)

### D5. The bar is the system's; its look follows the routing kind

The navigation bar is visible and hidden only on the root (the welcome pages)
through `setNavigationBarHidden(_:animated:)` in `willShow`. "Back" is the
system's on every pushed screen. The bar's look is set per hosting
controller by its routing kind, so every screen looks as it does today on
every device:

- a `.slidePush` screen (the steps) gets a transparent appearance
  (`UINavigationBarAppearance.configureWithTransparentBackground()` on the
  controller's `navigationItem.standardAppearance`/`scrollEdgeAppearance`),
  no title and `backButtonDisplayMode = .minimal`, which is what the drawn
  bar imitated;
- a `.push` screen (the recovery flow) keeps the default bar, its
  `navigationTitle` and the labelled Back, as under today's `NavigationStack`.

The Recovery Kit's gear cannot be a SwiftUI `.toolbar` item: the probe shows
such items of a hosted screen never enter the vertical bar. It becomes a
`UIBarButtonItem` (an image item, which the probe shows going vertical) on
the hosting controller's `navigationItem`, declared by the screen through a
CommonUI modifier (e.g. `flowBarItem(image:action:)`) that writes a model the
hosting controller observes — the same shape as D4's progress model. On the
Settings path the screen keeps its `.toolbar`, so the gear is declared both
ways there, as today. `slideToolbarTrailingItems` and
`slideNavigationButtonLabel` go. The steps' top paddings
(`OnboardingStepsStack.Constants`, `MasterPasswordView.Constants`) lose the
44 pt that stood in for the bar, since the bar now sits in the safe area; on
the Duo there is no top bar, so the layout follows the safe area, not a
constant.

### D6. The recovery flow rides the same stack

"Recover / Synchronize" pushes `VaultRecoveryView` onto the stack as `.push`,
and the recovery routers' `.push` destinations (select, camera, enter
password, import …) push onto it too, with the system transition. Their
sheets, matched-zoom transitions, file importer and alerts are unchanged.
This is the same shape as today's outer `NavigationStack`, only UIKit-backed.

### D7. What stays as it is

Keyboard hiding with the 500 ms wait before a push or a pop that a presenter
drives (today's `SlideNavigationStack` behaviour); the system Back button and
the swipe pop at once, the keyboard leaving with the transition as UIKit does
everywhere else — the builder verifies this on the Master Password step,
whose field is focused. `dismissFlow`/`onLogin` reaching `RootFlowController`,
the lock and logout behaviour, the module interactors, presenters and views
of every step. `OnboardingStepsStack` stays
as the name of the SwiftUI-side entry if the builder finds it useful for
previews; previews may wrap the controller in a preview-only representable.

## Constraints

- Deployment target iOS 18; `topBarPinnedTrailing`, `verticalBarEdge` and the
  compression APIs are iOS 27.1 (`#available`).
- `Router` and the routing modifiers live in CommonUI; the onboarding, the
  Master Password and the Recovery Kit modules are app modules. Nothing
  Duo-specific may leak into Data.
- AGENTS.md rules apply: stateless routers, callbacks as destination
  associated values, one `NavigationStack` per flow, presenters' observation
  in `onAppear`/`onDisappear`.

## Verification

Manual, on the simulators the machine has: iPhone (iOS 18 and iOS 27.1) for
unchanged looks and transitions, iPhone Duo folded and unfolded in landscape
for the vertical bar on every onboarding step, the Recovery Kit step and two
recovery screens; back by button on each and by swipe on the recovery
screens, no swipe on the steps; the shield fixed while
steps slide; a step's `destination` consistent after a system pop (push the
same step again). The throwaway probe (`SIMCTL_CHILD_DUO_PROBE`, patch kept
outside the repo) is the model for a quick check without taps.

## Decided after the builder check

- The bar's look is per routing kind (D5), so the recovery screens keep
  their titles and labelled Back.
- The gear is a `UIBarButtonItem` through a modifier and a model (D5), after
  the probe of a hosted `.toolbar`.
- The keyboard wait applies to presenter-driven navigation only (D7).
- "Pop me" unwinds to the screen that cleared its `destination` (D3).
- No edge swipe on the slide-pushed steps, swipe on the `.push` screens (D2;
  the person's choice).

## Left to the builder

- Whether the welcome pages → first step transition is the system's or the
  slide (D2 supports both; the product's choice).
- The environment value's name and shape, and where the pushed screen's
  routing kind is kept (the hosting controller subclass is the obvious home).
- Whether `SlideNavigationController` keeps `SlideAnimator` as a nested
  private type or the file keeps its name.
