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

5. **A group's layers stack in the order the caller gave them** (`4.2.7-fleuron.4`). Layers were
   drawn in `CrossModel.info`'s order, which is the order each portal was first registered — the
   first time it ever flew, not this flight. A caller that sorted its items for stacking (Fleuron's
   Home fan, middle book in front) got that order only on a first flight; afterwards, whenever the
   fan's order differed from the order its books were first seen, the returning covers overlapped
   wrongly and then snapped into place when the real views took over. `PortalInfo.layerOrder` is
   now set from each item's index in the group on every flight, and `PortalLayerView` draws each
   layer at that `zIndex`. Single portals keep 0, as before.

6. **A flight whose end is still moving follows it without zigzagging** (`4.2.7-fleuron.4`).
   Fleuron's Home flies its fan objects home while Home itself is still scaling back into place,
   so the end each object flies to moves on every frame. Two things made the objects shake against
   it, measured frame by frame from inside the app:
   - `Portal`'s anchor handler applied each new anchor on a `Task`, one run-loop turn after the
     layout that measured it. The animation's tick and the new anchor therefore arrived on
     alternate frames: the layer stepped on toward a stale target, then back as the target caught
     up — a direction change on almost every frame. The handler now applies it in the same update
     (`MainActor.assumeIsolated`).
   - The layer animated its frame and offset to a fixed end; an end that moved was applied to that
     offset unanimated, on top of the spring. The layer now animates one `progress` value
     (`PortalLayerPlacement`) and works its frame out from both ends' current rectangles, so a
     moving end moves it by its share of the remaining way.
   After both, each object's per-frame path changes direction one to three times in a whole flight.
7. **Only the end being flown to is followed; the end left behind holds still** (`4.2.7-fleuron.5`).
   Change 6 followed *both* ends live, and going forward the end left behind moves too: as a
   Fleuron page opens, Home zooms in towards its card, carrying the fan the objects leave up and
   to the left (measured: from (37, 292) to (−161, 235) during the flight). Early in the flight,
   while the layer is still close to that end, it was pulled off with it before it turned for
   its place — a visible swerve. `PortalLayerContentView` now keeps the departing end's rectangle
   from the moment `animateView` changes (the source going forward, the destination coming back),
   tagged with its direction so the first frame of a flight back never reads the flight out's.
   The end being flown to is still followed live, so change 6's smooth return is untouched; on
   Fleuron's close the destination never moved, so freezing it there changes nothing.
