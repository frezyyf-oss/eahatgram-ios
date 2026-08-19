import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

// MARK: - State

private struct EahatGramRatingState: Equatable {
    var levelText: String
    var starsText: String
    var isApplying: Bool
    var appliedAt: Int?

    static let initial = EahatGramRatingState(levelText: "", starsText: "", isApplying: false, appliedAt: nil)
}

// MARK: - Arguments

private final class EahatGramRatingArguments {
    let updateLevel: (String) -> Void
    let updateStars: (String) -> Void
    let apply: () -> Void

    init(
        updateLevel: @escaping (String) -> Void,
        updateStars: @escaping (String) -> Void,
        apply: @escaping () -> Void
    ) {
        self.updateLevel = updateLevel
        self.updateStars = updateStars
        self.apply = apply
    }
}

// MARK: - Sections / Entries

private enum EahatGramRatingSection: Int32 {
    case current
    case input
    case action
}

private enum EahatGramRatingEntry: ItemListNodeEntry {
    case currentHeader
    case currentLevel(Int32?)
    case currentStars(Int64?)

    case inputHeader
    case levelInput(String)
    case starsInput(String)
    case inputFooter

    case applyButton(Bool) // enabled

    var section: ItemListSectionId {
        switch self {
        case .currentHeader, .currentLevel, .currentStars:
            return EahatGramRatingSection.current.rawValue
        case .inputHeader, .levelInput, .starsInput, .inputFooter:
            return EahatGramRatingSection.input.rawValue
        case .applyButton:
            return EahatGramRatingSection.action.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .currentHeader: return 0
        case .currentLevel:  return 1
        case .currentStars:  return 2
        case .inputHeader:   return 3
        case .levelInput:    return 4
        case .starsInput:    return 5
        case .inputFooter:   return 6
        case .applyButton:   return 7
        }
    }

    static func < (lhs: EahatGramRatingEntry, rhs: EahatGramRatingEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! EahatGramRatingArguments
        switch self {

        case .currentHeader:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "ТЕКУЩИЙ РЕЙТИНГ",
                sectionId: self.section
            )

        case .currentLevel(let level):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: "Уровень",
                label: level.map { "\($0)" } ?? "—",
                labelStyle: .text,
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: nil
            )

        case .currentStars(let stars):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: "Звёзды",
                label: stars.map { "⭐ \($0)" } ?? "—",
                labelStyle: .text,
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: nil
            )

        case .inputHeader:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "УСТАНОВИТЬ",
                sectionId: self.section
            )

        case .levelInput(let text):
            return ItemListSingleLineInputItem(
                presentationData: presentationData,
                title: NSAttributedString(string: "Уровень", attributes: [.foregroundColor: presentationData.theme.list.itemPrimaryTextColor]),
                text: text,
                placeholder: "1 — 9999",
                type: .number,
                clearType: .always,
                maxLength: 6,
                sectionId: self.section,
                textUpdated: { args.updateLevel($0) },
                action: {}
            )

        case .starsInput(let text):
            return ItemListSingleLineInputItem(
                presentationData: presentationData,
                title: NSAttributedString(string: "Звёзды", attributes: [.foregroundColor: presentationData.theme.list.itemPrimaryTextColor]),
                text: text,
                placeholder: "0 — 999 999 999",
                type: .number,
                clearType: .always,
                maxLength: 12,
                sectionId: self.section,
                textUpdated: { args.updateStars($0) },
                action: {}
            )

        case .inputFooter:
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain("Значения записываются в локальный профиль и сразу отображаются в приложении."),
                sectionId: self.section
            )

        case .applyButton(let enabled):
            return ItemListActionItem(
                presentationData: presentationData,
                title: "Применить",
                kind: enabled ? .generic : .disabled,
                alignment: .center,
                sectionId: self.section,
                style: .blocks,
                action: { if enabled { args.apply() } }
            )
        }
    }
}

// MARK: - Entries builder

private func buildRatingEntries(
    state: EahatGramRatingState,
    currentRating: TelegramStarRating?
) -> [EahatGramRatingEntry] {
    let level = Int32(state.levelText)
    let stars = Int64(state.starsText)
    let canApply = (level != nil || stars != nil) && !state.isApplying

    return [
        .currentHeader,
        .currentLevel(currentRating?.level),
        .currentStars(currentRating?.stars),
        .inputHeader,
        .levelInput(state.levelText),
        .starsInput(state.starsText),
        .inputFooter,
        .applyButton(canApply)
    ]
}

// MARK: - Controller

public func eahatGramRatingController(context: AccountContext) -> ViewController {
    let statePromise = ValuePromise(EahatGramRatingState.initial, ignoreRepeated: true)
    let stateValue = Atomic(value: EahatGramRatingState.initial)
    let updateState: ((EahatGramRatingState) -> EahatGramRatingState) -> Void = { f in
        statePromise.set(stateValue.modify(f))
    }

    var dismissInputImpl: (() -> Void)?
    var presentSuccessImpl: (() -> Void)?

    let arguments = EahatGramRatingArguments(
        updateLevel: { text in updateState { s in var s = s; s.levelText = text; return s } },
        updateStars: { text in updateState { s in var s = s; s.starsText = text; return s } },
        apply: {
            let current = stateValue.with { $0 }
            let newLevel = Int32(current.levelText)
            let newStars = Int64(current.starsText)

            updateState { s in var s = s; s.isApplying = true; return s }
            dismissInputImpl?()

            let _ = context.account.postbox.transaction { transaction -> Void in
                guard let cached = transaction.getPeerCachedData(peerId: context.account.peerId) as? CachedUserData else {
                    return
                }
                let existing = cached.starRating
                let rating = TelegramStarRating(
                    level: newLevel ?? existing?.level ?? 0,
                    currentLevelStars: existing?.currentLevelStars ?? 0,
                    stars: newStars ?? existing?.stars ?? 0,
                    nextLevelStars: existing?.nextLevelStars
                )
                transaction.updatePeerCachedData(peerIds: Set([context.account.peerId])) { _, current in
                    return (current as? CachedUserData)?.withUpdatedStarRating(rating) ?? current
                }
            }.start(completed: {
                Queue.mainQueue().async {
                    updateState { s in var s = s; s.isApplying = false; return s }
                    presentSuccessImpl?()
                }
            })
        }
    )

    // Read current star rating from cached user data
    let currentRatingSignal: Signal<TelegramStarRating?, NoError> = context.account.postbox.peerView(id: context.account.peerId)
    |> map { view -> TelegramStarRating? in
        return (view.cachedData as? CachedUserData)?.starRating
    }
    |> distinctUntilChanged { a, b in a == b }

    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        currentRatingSignal
    )
    |> map { presentationData, state, currentRating -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Рейтинг и уровень"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: buildRatingEntries(state: state, currentRating: currentRating),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)

    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    presentSuccessImpl = { [weak controller] in
        guard let controller else { return }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller.present(
            UndoOverlayController(
                presentationData: presentationData,
                content: .succeed(text: "Рейтинг обновлён", timeout: nil, customUndoText: nil),
                elevatedLayout: false,
                action: { _ in return false }
            ),
            in: .current
        )
    }

    return controller
}
