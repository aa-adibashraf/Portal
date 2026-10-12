# Fleuron's fork of Portal

Branched from upstream **4.2.6** (`d097cf1`), the version Fleuron ships against. Upstream 6.x
requires a namespace on every transition, so moving to it is a separate migration.

## Changes

1. **`Portal.body` writes to `CrossModel` only when a value changed.** `CrossModel` is
   `@Observable`; any write to `info` invalidates every view that reads it, including every
   Portal's `opacity` and `index`. The anchor-preference handler runs on every layout pass —
   every scroll frame — and wrote the group id and the anchor each time, so all portals
   re-rendered continuously. Measured on an iPhone 16 Pro Max (Release, 10 Oct 2026): 235 ms of
   main-thread time in a two-minute session, plus the re-renders it caused. Still present
   unchanged in upstream 6.1.0.
2. **`GroupItemPortalTransitionModifier.configureGroupPortals` sets each item's configuration in
   one write** instead of six.

`Anchor<CGRect>` is `Equatable`, so an anchor that genuinely moved still compares unequal and is
written: the animated layer keeps following live layout.

3. **A landed portal's anchor waits outside `CrossModel.info`** (`4.2.7-fleuron.2`). After a
   forward flight lands (`hideView` true) its layer is hidden and reads nothing, but its views
   still report their anchors on every layout pass, and as a list scrolls those anchors really do
   change, so change 1 alone still wrote them and re-rendered every Portal on screen each frame,
   each one then searching `info` for its own entry. They now go into the unobserved
   `CrossModel.restingAnchors`, and `publishRestingAnchors(at:)` moves them into `info` the
   moment a reverse flight begins (every place that sets `hideView = false`), so the layer still
   flies from where the view really is. Measured on an iPhone 16 Pro Max (Release, 12 Oct 2026),
   scrolling a Library of covers that had flown in: dropped-frame time 20% -> 2.7%.

4. **A layer outlives its handover by 34 ms** (`4.2.7-fleuron.3`). The layer is drawn in Portal's
   own overlay window, which commits its frames apart from the app's window. Landing hid the
   layer in the same update that showed the destination, and returning cleared it in the same
   update that showed the source — but the two windows could show those changes a frame apart,
   and for that frame neither object was drawn: on an iPhone simulator recording, the Library
   showed through a book page as it opened, and the cell stood empty as the jacket came home.
   `CrossModel.land(at:)` now shows the destination at once and keeps the layer (`layerLingers`)
   for 34 ms; `retire(at:)` shows the source at once (`sourceRevealed`) and clears the layer and
   its anchors 34 ms later, unless a new flight has started (`handoverToken`). For those frames
   the layer and the real view draw the same picture in the same place. `PortalPrivate` is
   unchanged.
