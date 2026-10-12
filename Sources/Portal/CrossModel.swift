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

    /// How long the layer outlives a handover. See `land(at:)`.
    public static let layerHandover: TimeInterval = 0.034

    /// A forward flight has arrived: the destination shows now, and the layer goes a moment later.
    ///
    /// The layer is drawn in Portal's own overlay window, which commits its frames separately from
    /// the app's. Hidden in the same update that showed the destination, the layer could leave a
    /// frame before the destination arrived, and for that frame neither was drawn — whatever lay
    /// behind showed through. Kept for two frames more, the two overlap exactly instead.
    /// (Fleuron fork; see FLEURON-FORK.md.)
    public func land(at index: Int) {
        guard info.indices.contains(index) else { return }
        info[index].layerLingers = true
        info[index].hideView = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.layerHandover) { [weak self] in
            guard let self, self.info.indices.contains(index), self.info[index].hideView,
                  self.info[index].layerLingers else { return }
            self.info[index].layerLingers = false
        }
    }

    /// A reverse flight has arrived home: the source shows now, and the layer and its anchors are
    /// cleared a moment later, for the reason `land(at:)` gives. (Fleuron fork.)
    public func retire(at index: Int) {
        guard info.indices.contains(index) else { return }
        let token = UUID()
        info[index].sourceRevealed = true
        info[index].handoverToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.layerHandover) { [weak self] in
            guard let self, self.info.indices.contains(index),
                  self.info[index].handoverToken == token else { return }
            var cleared = self.info[index]
            cleared.initialized = false
            cleared.layerView = nil
            cleared.sourceAnchor = nil
            cleared.destinationAnchor = nil
            cleared.sourceRevealed = false
            cleared.handoverToken = nil
            self.info[index] = cleared
        }
    }

    /// Initializes a new CrossModel instance.
    /// Creates empty arrays for managing portal information.
    public init() {}
}
