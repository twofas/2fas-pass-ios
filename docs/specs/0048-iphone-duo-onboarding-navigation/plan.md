# iPhone Duo onboarding navigation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The onboarding (welcome pages, the six steps, the recovery flow) runs in one UIKit navigation stack whose bar the system owns, so iPhone Duo puts "Back" and the Recovery Kit gear in its vertical bar, while the steps keep their slide transition and the progress shield stays fixed above them.

**Architecture:** `SlideNavigationStack` (a `UIViewControllerRepresentable` around a hidden-bar `UINavigationController`) becomes `SlideNavigationController`, a `UINavigationController` subclass the onboarding flow controller places in `RootViewController`. Every screen stays a SwiftUI view in a `UIHostingController`; the router reaches the stack through a new environment value, the shield through a model the host's root feeds from the existing preferences, and the gear through a preference the host turns into a `UIBarButtonItem`.

**Tech Stack:** Swift 6, SwiftUI + UIKit, iOS 18 deployment target, Xcode 27.1 / iOS 27.1 SDK. No unit-test target covers CommonUI or the app modules (`DataTests` is Data only), so each task is verified by one `2PASS` build and by the simulators named in the task.

**Spec:** `docs/specs/0048-iphone-duo-onboarding-navigation/design.md`

## Global Constraints

- Deployment target iOS 18.0; iOS 27.1 API only under `#available(iOS 27.1, *)`.
- Build: from `2PASS/`, `xcodebuild -scheme 2PASS -configuration Debug -destination 'platform=iOS Simulator,id=<simulator>' build | xcbeautify --quiet` — one build per task, the Duo simulator id on this machine is `5BEBB7DF-4967-49CA-B73D-F003D6D0C1BE`; `xcrun simctl list devices available` names the iPhone ones.
- AGENTS.md: a comment block is separated from preceding code by a blank line; every extension body starts with a blank line; new file headers carry the current year (2026); routers are stateless; `Impl` suffix for a protocol's one implementation; main-actor classes use `isolated deinit`; presenters' observation in `onAppear`/`onDisappear`.
- Commit messages: a title line only, no body, no trailer (user preference).
- Spec anti-goals: no `toolbarVerticalBehavior(.disabled)`, no hand-drawn bar, no navigation controller inside a `UIViewControllerRepresentable`, no second stack inside the onboarding.
- Out of scope: AutoFill's representable, the Settings variant of the Recovery Kit screen (keeps its `.toolbar`), orientations, the rest of the app.

## Review Focus

1. Master Password step with a field focused, system Back tapped: the screen pops at once and the keyboard leaves with the transition, no 500 ms delay and no stuck keyboard (D7). Pinned in Task 7, check 5.
2. Recovery: on the "try again" path `VaultRecoverySelectPresenter` clears its `destination` while two screens sit above it — both pop in one animation and their own routers end with `destination == nil`, so pushing the same screen again works (D3). Pinned in Task 7, check 6.
3. A step popped by the system Back, then pushed again from the step below: the second push happens (the lower step's `destination` was cleared by `onPop`), no duplicate push, no dead button. Pinned in Task 7, check 4.
4. Folded Duo on a step and on a recovery screen: the content is inset left of the vertical bar (the Continue button never under the status column) and the shield neither overlaps the bar nor the content (there is no top bar there, so the 106 pt content padding must still clear the 60 pt shield). Pinned in Task 7, checks 2–3.
5. Logout/lock in the middle of a step (`RootFlowController.clearActiveViewController`): the navigation controller, its hosts and the overlay deallocate — the environment actions capture the host weakly — and the next onboarding start is a fresh stack. Pinned in Task 7, check 7.

## File structure

| File | Responsibility |
| --- | --- |
| `2PASS/CommonUI/Architecture/FlowNavigation.swift` (new) | `FlowPushKind`, `FlowNavigationAction` and its environment key; the `flowBarTrailingItem` modifier and its preference. |
| `2PASS/CommonUI/Architecture/SlideNavigationController.swift` (new) | The `UINavigationController` subclass: hosting, per-kind bar look, transitions, pop sync, keyboard wait, overlay. `SlideAnimator` moves here as a private type. |
| `2PASS/CommonUI/DesignSystem/SlideNavigationStack.swift` | Deleted in Task 6. |
| `2PASS/CommonUI/Architecture/Router.swift` | `.push`/`.slidePush` go to `flowNavigation` when present; the preference-based slide push goes. |
| `2PASS/2PASS/Modules/Onboarding/OnboardingStepsStack.swift` | Keeps the two preference keys and three modifiers; gains `OnboardingProgress`, `OnboardingProgressReporter` and `OnboardingProgressOverlayView`; loses the `OnboardingStepsStack` view. |
| `2PASS/2PASS/Modules/Onboarding/OnboardingFlowController.swift` | Builds the controller, decorates every host, installs the overlay. |
| `2PASS/2PASS/Modules/Onboarding/OnboardingPages/OnboardingPagesRouter.swift` | No `NavigationStack`; both destinations `.push`. |
| `2PASS/2PASS/Modules/VaultDecryptionKit/VaultDecryptionKitView.swift` | Gear as `flowBarTrailingItem` in onboarding, `.toolbar` in Settings. |
| `2PASS/2PASS/Modules/MasterPassword/MasterPasswordView.swift` | 44 pt removed from the hidden-progress padding; preview. |
| Previews in `SetupVaultView`, `GenerateSecretKeyView`, `HalfwayView`, `SetupCompleteView` | Drop the `OnboardingStepsStack` wrapper. |

---

### Task 1: The flow-navigation environment and the bar-item preference

**Files:**
- Create: `2PASS/CommonUI/Architecture/FlowNavigation.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum FlowPushKind: Sendable { case system, slide }

  @MainActor
  public struct FlowNavigationAction {
      public init(push: @escaping (AnyView, FlowPushKind, @escaping @MainActor () -> Void) -> Void,
                  pop: @escaping () -> Void)
      /// `onPop` runs once when the pushed screen leaves the stack by any route (system Back, swipe, programmatic pop).
      public func push(_ view: AnyView, kind: FlowPushKind, onPop: @escaping @MainActor () -> Void)
      /// Pops back to the screen this action was handed to, removing everything above it.
      public func pop()
  }

  extension EnvironmentValues { public var flowNavigation: FlowNavigationAction? }   // default nil

  public struct FlowBarItem: Equatable {       // == compares `systemImage` only
      public let systemImage: String
      public let action: @MainActor () -> Void
  }
  struct FlowBarTrailingItemPreferenceKey: PreferenceKey   // value FlowBarItem?, reduce: last non-nil wins
  extension View { public func flowBarTrailingItem(systemImage: String, action: @escaping @MainActor () -> Void) -> some View }
  ```

- [ ] **Step 1: Create the file with the types above**

`FlowNavigationAction` stores the two closures and forwards to them. The environment key's default is `nil`. The preference key is internal: Task 2's controller reads it in the same module.

- [ ] **Step 2: Build**

Run the build command from Global Constraints on an iPhone simulator. Expected: `Build Succeeded`.

- [ ] **Step 3: Commit**

```bash
git add 2PASS/CommonUI/Architecture/FlowNavigation.swift
git commit -m "CommonUI: flow-navigation environment action and the trailing bar-item preference"
```

---

### Task 2: `SlideNavigationController`

**Files:**
- Create: `2PASS/CommonUI/Architecture/SlideNavigationController.swift`
- Read: `2PASS/CommonUI/DesignSystem/SlideNavigationStack.swift` (`SlideAnimator`, the keyboard wait; deleted in Task 6)

**Interfaces:**
- Consumes: Task 1's types.
- Produces:
  ```swift
  @MainActor
  public final class SlideNavigationController: UINavigationController {
      /// `decorate` wraps every hosted screen, root included (environment, tint, readers).
      public init<Root: View>(root: Root, decorate: @escaping (AnyView) -> AnyView)
      /// A passthrough SwiftUI layer over the whole stack, pinned to the view's edges.
      public func setOverlay<Overlay: View>(_ overlay: Overlay)
  }
  ```

- [ ] **Step 1: Write the controller**

Private pieces, in this file:

- `HostedScreen: UIHostingController<AnyView>` with `let kind: FlowPushKind`, `var onPop: (@MainActor () -> Void)?`, `var trailingItem: FlowBarItem?` whose `didSet` sets `navigationItem.rightBarButtonItem` to a `UIBarButtonItem(image: UIImage(systemName:), primaryAction: UIAction { item.action() })` or `nil`. A `.slide` host sets on its `navigationItem` a `UINavigationBarAppearance` with `configureWithTransparentBackground()` as `standardAppearance`, `scrollEdgeAppearance` and `compactAppearance`; a `.system` host leaves the defaults.
- `host(_ view: AnyView, kind: FlowPushKind) -> HostedScreen`: wraps `decorate(view)` with `.environment(\.flowNavigation, action(for: host))` and `.onPreferenceChange(FlowBarTrailingItemPreferenceKey.self) { [weak host] in host?.trailingItem = $0 }`. `action(for:)` captures the host weakly: push → `push(view, kind:, onPop:)`; pop → `popToViewController(host, animated: true)`.
- `push(_:kind:onPop:)` and the pop: if `keyboardObserver.isKeyboardVisible`, `UIApplication.shared.hideKeyboard()` and wait 500 ms (`Task.sleep`, as today) before the UIKit call; `KeyboardObserver` is CommonUI's.
- Delegate (`self`): `animationControllerFor` returns `SlideAnimator(isPresenting: operation == .push)` when the screen entering on push, or leaving on pop, is a `.slide` host; otherwise `nil`. `willShow`: `setNavigationBarHidden(viewController === viewControllers.first, animated:)`; the screen below the shown one gets `navigationItem.backButtonDisplayMode = .minimal` when the shown one is `.slide`, `.default` otherwise (the back button a screen shows belongs to the item below it). `didShow`: `interactivePopGestureRecognizer?.isEnabled = (top is a `.system` host)`; every `HostedScreen` of the previous `viewControllers` snapshot missing from the current one gets its `onPop` called once and cleared.
- `setOverlay`: a `UIHostingController` child with `.clear` background, `view.isUserInteractionEnabled = false`, pinned to all four edges of `view`, above the navigation bar (`view.bringSubviewToFront` after `addChild`).
- `SlideAnimator` copied verbatim from `SlideNavigationStack.swift` as `private final class`.

The root is `host(AnyView(root), kind: .system)`; `backButtonDisplayMode` is left to `willShow`.

- [ ] **Step 2: Build**

Expected: `Build Succeeded` (nothing uses the controller yet).

- [ ] **Step 3: Commit**

```bash
git add 2PASS/CommonUI/Architecture/SlideNavigationController.swift
git commit -m "CommonUI: SlideNavigationController, a system-owned bar with the slide transition per push"
```

---

### Task 3: The router pushes onto the flow stack

**Files:**
- Modify: `2PASS/CommonUI/Architecture/Router.swift` (`RoutingModifier`, `RoutingNavigationStackByItemModifier`, the `slideNavigationDestination` call at ~line 114)

**Interfaces:**
- Consumes: `FlowNavigationAction`, `FlowPushKind` (Task 1).
- Produces: unchanged public API (`router(router:destination:)` overloads, `RoutingType.slidePush` kept).

- [ ] **Step 1: Route `.push` and `.slidePush` to `flowNavigation` when present**

In `RoutingModifier`: add `@Environment(\.flowNavigation) private var flowNavigation` and a latch `@State private var flowPushItem: R.Destination?`. In `sync()`:
- when `flowNavigation != nil` and `target` is `.push` or `.slidePush` and `flowPushItem == nil`: latch, then `flowNavigation.push(AnyView(router.view(for: liveValue(for: destination))), kind: target == .slidePush ? .slide : .system, onPop: { flowPushItem = nil; clearDestination(afterDismissing: destination) })`;
- when `flowPushItem != nil` and `target` is neither `.push` nor `.slidePush`: unlatch and `flowNavigation.pop()`.
Remove `slidePushItem`, `slidePushBinding` and the `.slideNavigationDestination` modifier; `.slidePush` without `flowNavigation` does nothing (as a `.push` without a stack does today).

- [ ] **Step 2: Keep the SwiftUI push path off when the flow stack is present**

`RoutingNavigationStackByItemModifier.pushDestinationProxy` returns `false` and ignores sets while `@Environment(\.flowNavigation)` is non-nil, so no `navigationDestination` fires outside a `NavigationStack`.

- [ ] **Step 3: Build**

Expected: `Build Succeeded`; `SlideNavigationStack.swift` still compiles (its `slideNavigationDestination` is now unused).

- [ ] **Step 4: Commit**

```bash
git add 2PASS/CommonUI/Architecture/Router.swift
git commit -m "Router: push and slidePush go to the flow stack when the environment carries one"
```

---

### Task 4: The onboarding progress model, reporter and overlay

**Files:**
- Modify: `2PASS/2PASS/Modules/Onboarding/OnboardingStepsStack.swift`

**Interfaces:**
- Produces:
  ```swift
  @MainActor @Observable final class OnboardingProgress { var progress: Float = 0; var isVisible: Bool = false }
  /// Wraps one hosted screen: reads its progress preferences and writes the model, on change and on every appearance.
  struct OnboardingProgressReporter<Content: View>: View { init(progress: OnboardingProgress, content: Content) }
  /// The shield above the stack; `Constants.progressTopPadding` (44 + 16) and the two animations as today.
  struct OnboardingProgressOverlayView: View { init(progress: OnboardingProgress) }
  ```
  `onboardingStepProgress(_:)`, `onboardingStepProgressVisibility(_:)`, `onboardingStepTopPadding(adjust:)` and both preference keys stay as they are; `Constants.contentTopPadding` becomes `106` (the bar now sits in the safe area).

- [ ] **Step 1: Replace the `OnboardingStepsStack` view with the three types above**

`OnboardingProgressReporter` keeps `@State private var claimed: (progress: Float, isVisible: Bool)` from `onPreferenceChange` of both keys (visibility `nil` → `true` for a screen that set progress, `false` for one that set nothing: keep a third state "claimedProgress: Bool" so an unclaimed screen hides the shield), and applies `claimed` to the model in `onAppear` and in `onChange(of:)`. The overlay view renders `ProgressView(value: progress.progress)` with `ShieldProgressStyle`, top-aligned, `.animation(.default, value: progress.progress)`, the visibility with `.easeInOut(duration: Constants.changeProgressAnimationDuration)` and `.transition(.opacity)`, and `allowsHitTesting(false)`.

- [ ] **Step 2: Build**

Expected: errors only at the five previews and `OnboardingPagesRouter` that still name `OnboardingStepsStack` — fixed in Tasks 5 and 6. If the executor prefers a green build per task, do Step 1 of Task 6 (the previews) inside this task.

- [ ] **Step 3: Commit** (with Task 5 if the build is red here)

```bash
git add 2PASS/2PASS/Modules/Onboarding/OnboardingStepsStack.swift
git commit -m "Onboarding: progress model, per-host reporter and the shield overlay replace the steps stack view"
```

---

### Task 5: The onboarding flow owns the stack

**Files:**
- Modify: `2PASS/2PASS/Modules/Onboarding/OnboardingFlowController.swift`
- Modify: `2PASS/2PASS/Modules/Onboarding/OnboardingPages/OnboardingPagesRouter.swift`

**Interfaces:**
- Consumes: `SlideNavigationController` (Task 2), `OnboardingProgress`, `OnboardingProgressReporter`, `OnboardingProgressOverlayView` (Task 4), `DismissFlowAction` (`2PASS/Common/SwiftUI/DismissFlowAction.swift`).
- Produces: `OnboardingFlowController.embedAsRoot(in:parent:)` returns the `SlideNavigationController` (still a `UIViewController`, as `RootFlowController.toOnboarding` expects).

- [ ] **Step 1: Build the controller in `embedAsRoot`**

```swift
let progress = OnboardingProgress()
let navigation = SlideNavigationController(root: OnboardingPagesRouter.buildView(onLogin: …)) { screen in
    AnyView(
        OnboardingProgressReporter(progress: progress, content: screen)
            .environment(\.dismissFlow, DismissFlowAction(action: { [weak parent] in parent?.onboardingToLoggedIn() }))
            .tint(.brand500)
    )
}
navigation.setOverlay(OnboardingProgressOverlayView(progress: progress))
navigation.view.backgroundColor = UIColor(resource: .mainBackground)
flowController.navigationController = navigation
viewController.placeChild(navigation)
return navigation
```
Remove the dead `vc.navigationController?.navigationItem.backButtonDisplayMode = .minimal` line.

- [ ] **Step 2: Strip `OnboardingPagesRouter`**

`buildView` returns `OnboardingPagesView(presenter: OnboardingPagesPresenter())` alone (no `NavigationStack`, no environment, no tint — the flow controller decorates). `routingType`: `.getStarted` and `.recover` both `.push` (the system transition from the pages, see spec D2). `view(for:)`: `.getStarted` → `SetupVaultRouter.buildView()`, `.recover` → `VaultRecoveryRouter.buildView()`.

- [ ] **Step 3: Build and run on an iPhone simulator with a fresh install**

Run the build; then `xcrun simctl uninstall`/`install`/`launch` of `com.twofas.org.TwoPASS.dev` on an iPhone simulator. Expected: welcome pages without a bar; "Get Started" pushes the first step with the system transition, a chevron-only Back and the shield at the top; the previews still fail to compile until Task 6.

- [ ] **Step 4: Commit**

```bash
git add 2PASS/2PASS/Modules/Onboarding/OnboardingFlowController.swift 2PASS/2PASS/Modules/Onboarding/OnboardingPages/OnboardingPagesRouter.swift
git commit -m "Onboarding: one SlideNavigationController owns the pages, the steps and the recovery flow"
```

---

### Task 6: The gear, the paddings, the previews, the old stack

**Files:**
- Modify: `2PASS/2PASS/Modules/VaultDecryptionKit/VaultDecryptionKitView.swift` (lines 25–31 body switch, 85–93 toolbar, 112–119 `settingsButton`)
- Modify: `2PASS/2PASS/Modules/MasterPassword/MasterPasswordView.swift:11` and the preview at ~270
- Modify previews: `SetupVaultView.swift:~155`, `GenerateSecretKeyView.swift:~212`, `HalfwayView.swift:~123`, `SetupCompleteView.swift:~106`
- Delete: `2PASS/CommonUI/DesignSystem/SlideNavigationStack.swift`

**Interfaces:**
- Consumes: `flowBarTrailingItem(systemImage:action:)` (Task 1).

- [ ] **Step 1: The gear per kind**

In `body`: `.onboarding` adds `.flowBarTrailingItem(systemImage: "gearshape") { presenter.onSettings() }` after the progress modifiers; `.settings` keeps `.toolbar { ToolbarItem(placement: .primaryAction) { Button { presenter.onSettings() } label: { Image(systemName: "gearshape") } } }`. Remove `.slideToolbarTrailingItems`, the shared `.toolbar` on `content`, `settingsButton` and the `slideNavigationButtonLabel()` call.

- [ ] **Step 2: Paddings and previews**

`MasterPasswordView.Constants.contentTopPaddingForHideProgress = 16.0`. The five previews show the step view directly (`SetupVaultRouter.buildView()` etc.), no wrapper.

- [ ] **Step 3: Delete `SlideNavigationStack.swift`**

Run `grep -rn "SlideNavigationStack\|slideNavigationDestination\|slideToolbarTrailingItems\|slideNavigationButtonLabel\|OnboardingStepsStack {" 2PASS/2PASS 2PASS/CommonUI 2PASS/AutoFill` — expected: no matches.

- [ ] **Step 4: Build**

Expected: `Build Succeeded`, no warnings about unused `slidePush` paths.

- [ ] **Step 5: Commit**

```bash
git add -A 2PASS/2PASS/Modules/VaultDecryptionKit 2PASS/2PASS/Modules/MasterPassword 2PASS/2PASS/Modules/Onboarding 2PASS/CommonUI/DesignSystem/SlideNavigationStack.swift
git commit -m "Onboarding: the gear as a bar item, the bar's 44 pt out of the paddings, SlideNavigationStack removed"
```

---

### Task 7: Manual verification pass

**Files:** none. The person taps; the executor builds, installs (`xcrun simctl install` of the built `.app`, `uninstall` first for a fresh onboarding) and screenshots (`xcrun simctl io <id> screenshot --display=<display uuid> <file>`; the Duo's cover display is the default, `xcrun simctl io <id> enumerate` lists the inner one).

- [ ] **Check 1 — iPhone, iOS 18 and iOS 27.1 simulators:** welcome pages without a bar; "Get Started" system push; every step with the slide transition, chevron-only Back, transparent bar, shield fixed at the top and animating between steps; the Recovery Kit gear top-right opening Settings; "Recover / Synchronize" with the default bar, title where the screen sets one, labelled Back; swipe-back works on recovery screens and not on steps.
- [ ] **Check 2 — Duo folded, a step:** Back in the vertical bar under the status column, the gear below it on the Recovery Kit step, content inset left of the bar, shield not overlapping either.
- [ ] **Check 3 — Duo unfolded, landscape, a step and a recovery screen:** the same placement; portrait: horizontal bar as on iPhone.
- [ ] **Check 4 — pop consistency:** on step 2 tap system Back, then "Continue" on step 1 again: step 2 pushes again.
- [ ] **Check 5 — keyboard:** Master Password with a focused field, tap Back: immediate pop, keyboard leaves with the transition; then Continue from Halfway again, type, and the presenter-driven push to the Recovery Kit still hides the keyboard first.
- [ ] **Check 6 — recovery unwind:** reach the "try again" path of `VaultRecoverySelect` (an import failure), confirm two screens pop together and the flow can be re-entered.
- [ ] **Check 7 — logout mid-step:** background the app on a step (logout) and return: a fresh onboarding stack, no leftover shield; Xcode's memory graph shows one `SlideNavigationController`.
- [ ] **Record the outcome** in `docs/specs/0048-iphone-duo-onboarding-navigation/design.md` under a "Verification" note with the date, and in the memory index per the session rules.
