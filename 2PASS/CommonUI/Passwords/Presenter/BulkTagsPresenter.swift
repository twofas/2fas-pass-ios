// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Observation

struct BulkTagChanges {
    let tagsToAdd: Set<ItemTagID>
    let tagsToRemove: Set<ItemTagID>

    var isEmpty: Bool {
        tagsToAdd.isEmpty && tagsToRemove.isEmpty
    }
}

enum BulkTagsDestination: RouterDestination {
    case addTag(onClose: Callback)

    var id: String {
        switch self {
        case .addTag: "addTag"
        }
    }
}

protocol BulkTagsFlowControlling: AnyObject {
    func handleCancel()
    func handleConfirmChanges(_ changes: BulkTagChanges)
}

@Observable
final class BulkTagsPresenter {

    private let flowController: BulkTagsFlowControlling
    private let interactor: BulkTagsModuleInteracting
    private let selectedItemIDs: [ItemID]
    private let totalSelectedCount: Int

    private var initialStates: [ItemTagID: SelectionIndicatorState] = [:]
    private var currentStates: [ItemTagID: SelectionIndicatorState] = [:]
    private(set) var tagItems: [BulkTagSelectionItem] = []

    var destination: BulkTagsDestination?

    @ObservationIgnored
    var onChange: (() -> Void)?

    var hasPendingChanges: Bool {
        tagItems.contains { item in
            initialStates[item.tag.tagID] != currentStates[item.tag.tagID]
        }
    }

    init(
        flowController: BulkTagsFlowControlling,
        interactor: BulkTagsModuleInteracting,
        selectedItemIDs: [ItemID],
        tagCountsByID: [ItemTagID: Int]
    ) {
        self.flowController = flowController
        self.interactor = interactor
        self.selectedItemIDs = selectedItemIDs
        self.totalSelectedCount = selectedItemIDs.count

        loadTags(tagCountsByID: tagCountsByID)
    }

    func toggleTag(_ tag: ItemTagData) {
        guard let currentState = currentStates[tag.tagID] else { return }

        let initialState = initialStates[tag.tagID] ?? .unselected
        let nextState = nextCycleState(current: currentState, initial: initialState)

        currentStates[tag.tagID] = nextState
        updateTagItem(for: tag.tagID, newState: nextState)
        onChange?()
    }

    func handleCancel() {
        flowController.handleCancel()
    }

    func handleSave() {
        let changes = computeChanges()
        flowController.handleConfirmChanges(changes)
    }

    func onAddNewTag() {
        destination = .addTag(onClose: { [weak self] in
            self?.destination = nil
            self?.reloadTags()
        })
    }

    func state(for tagID: ItemTagID) -> SelectionIndicatorState {
        currentStates[tagID] ?? .unselected
    }

    // MARK: - Private

    private func loadTags(tagCountsByID: [ItemTagID: Int]) {
        let allTags = interactor.listAllTags()

        var items: [BulkTagSelectionItem] = []

        for tag in allTags {
            let count = tagCountsByID[tag.tagID] ?? 0
            let state = calculateInitialState(itemsWithTagCount: count)

            initialStates[tag.tagID] = state
            currentStates[tag.tagID] = state

            items.append(BulkTagSelectionItem(
                tag: tag,
                itemsWithTagCount: count,
                state: state
            ))
        }

        tagItems = items
    }

    private func reloadTags() {
        let allTags = interactor.listAllTags()

        var updatedItems: [BulkTagSelectionItem] = []

        for tag in allTags {
            if let existingItem = tagItems.first(where: { $0.tag.tagID == tag.tagID }) {
                updatedItems.append(BulkTagSelectionItem(
                    tag: tag,
                    itemsWithTagCount: existingItem.itemsWithTagCount,
                    state: currentStates[tag.tagID] ?? existingItem.state
                ))
            } else {
                let state = SelectionIndicatorState.unselected
                initialStates[tag.tagID] = state
                currentStates[tag.tagID] = state

                updatedItems.append(BulkTagSelectionItem(
                    tag: tag,
                    itemsWithTagCount: 0,
                    state: state
                ))
            }
        }

        tagItems = updatedItems
        onChange?()
    }

    private func updateTagItem(for tagID: ItemTagID, newState: SelectionIndicatorState) {
        guard let index = tagItems.firstIndex(where: { $0.tag.tagID == tagID }) else { return }
        let item = tagItems[index]
        tagItems[index] = BulkTagSelectionItem(
            tag: item.tag,
            itemsWithTagCount: item.itemsWithTagCount,
            state: newState
        )
    }

    private func calculateInitialState(itemsWithTagCount: Int) -> SelectionIndicatorState {
        guard itemsWithTagCount > 0 else { return .unselected }
        return itemsWithTagCount == totalSelectedCount ? .selected : .mixed
    }

    private func nextCycleState(
        current: SelectionIndicatorState,
        initial: SelectionIndicatorState
    ) -> SelectionIndicatorState {
        // Cycle: .mixed -> .selected -> .unselected -> .mixed
        switch current {
        case .mixed:
            return .selected
        case .selected:
            return .unselected
        case .unselected:
            // If initial was mixed, cycle back to mixed; otherwise stay in selected/unselected cycle
            return initial == .mixed ? .mixed : .selected
        }
    }

    private func computeChanges() -> BulkTagChanges {
        var tagsToAdd: Set<ItemTagID> = []
        var tagsToRemove: Set<ItemTagID> = []

        for tagItem in tagItems {
            let tagID = tagItem.tag.tagID
            let initial = initialStates[tagID] ?? .unselected
            let current = currentStates[tagID] ?? .unselected

            guard initial != current else { continue }

            switch (initial, current) {
            case (_, .selected):
                // Moving to selected: add tag to all items
                tagsToAdd.insert(tagID)
            case (_, .unselected):
                // Moving to unselected: remove tag from all items
                tagsToRemove.insert(tagID)
            case (_, .mixed):
                // Moving back to mixed means no change from initial mixed state
                break
            }
        }

        return BulkTagChanges(tagsToAdd: tagsToAdd, tagsToRemove: tagsToRemove)
    }
}

struct BulkTagSelectionItem: Identifiable {
    let tag: ItemTagData
    let itemsWithTagCount: Int
    let state: SelectionIndicatorState

    var id: ItemTagID { tag.tagID }
}
