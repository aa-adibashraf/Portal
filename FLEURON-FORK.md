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
