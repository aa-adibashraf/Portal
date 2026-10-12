//
//  CrossModel.swift
//  Portal
//
//  Created by Aether, 2025.
//
//  Copyright © 2025 Aether. All rights reserved.
//  Licensed under the MIT License.
//

import SwiftUI

/// Shared model for managing Portal animations and transitions.
///
/// This class serves as the central coordinator for portal animations, managing the state
/// and anchor information for both source and destination views. It tracks animation states,
/// opacity values, and coordinate transformations needed for smooth portal transitions.
///
/// The model uses the `@Observable` macro for SwiftUI integration and is marked with
/// `@MainActor` to ensure all UI-related operations happen on the main thread.
@MainActor @Observable
public class CrossModel {
    /// Array containing information about all active portal animations.
    /// Each `PortalInfo` object tracks the state of a specific portal transition.
    public var info: [PortalInfo] = []

    /// Array containing root-level portal information.
    /// Used for managing portal hierarchies and nested portal scenarios.
    public var rootInfo: [PortalInfo] = []

    /// Live anchors reported by portals whose layer is not flying, kept out of `info`.
    ///
    /// Every write to `info` invalidates every view reading it, which is every `Portal` on screen.
    /// A portal that has landed still reports its anchor on each layout pass, so a scrolled list of
    /// landed portals re-rendered all of them on every frame. Nothing reads a resting portal's
    /// anchor until its layer flies again, so the anchor waits here, unobserved, and
    /// `publishRestingAnchors(at:)` hands it over as a reverse flight begins. (Fleuron fork; see
    /// FLEURON-FORK.md.)
    @ObservationIgnored public var restingAnchors: [String: RestingAnchors] = [:]

    public struct RestingAnchors {
        public var source: Anchor<CGRect>?
        public var destination: Anchor<CGRect>?
    }

    /// Moves a portal's resting anchors into `info`, writing only what differs. Call before its
    /// layer flies again.
    public func publishRestingAnchors(at index: Int) {
        guard info.indices.contains(index),
              let resting = restingAnchors.removeValue(forKey: info[index].infoID) else { return }
        if let source = resting.source, info[index].sourceAnchor != source {
            info[index].sourceAnchor = source
        }
        if let destination = resting.destination, info[index].destinationAnchor != destination {
            info[index].destinationAnchor = destination
        }
    }

    /// Initializes a new CrossModel instance.
    /// Creates empty arrays for managing portal information.
    public init() {}
}
