import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class EahatGramArguments {
    let context: AccountContext
    let toggleGhost: (Bool) -> Void
    let openStats: () -> Void
    let openVisual: () -> Void

    init(
        context: AccountContext,
        toggleGhost: @escaping (Bool) -> Void,
        openStats: @escaping () -> Void,
        openVisual: @escaping () -> Void
    ) {
        self.context = context
        self.toggleGhost = toggleGhost
        self.openStats = openStats
        self.openVisual = openVisual
    }
}

private enum EahatGramSection: Int32 {
    case ghost
    case stats
    case visual
}

private enum EahatGramEntry: ItemListNodeEntry {
    case ghostHeader
    case ghostToggle(Bool)
    case ghostFooter
    case statsHeader
    case statsRow(Int)
    case statsFooter
    case visualHeader
    case visualRow
    case visualFooter

    var section: ItemListSectionId {
        switch self {
        case .ghostHeader, .ghostToggle, .ghostFooter:
            return EahatGramSection.ghost.rawValue
        case .statsHeader, .statsRow, .statsFooter:
            return EahatGramSection.stats.rawValue
        case .visualHeader, .visualRow, .visualFooter:
            return EahatGramSection.visual.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .ghostHeader:  return 0
        case .ghostToggle:  return 1
        case .ghostFooter:  return 2
        case .statsHeader:  return 3
        case .statsRow:     return 4
        case .statsFooter:  return 5
        case .visualHeader: return 6
        case .visualRow:    return 7
        case .visualFooter: return 8
        }
    }

    static func < (lhs: EahatGramEntry, rhs: EahatGramEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! EahatGramArguments
        switch self {
        case .ghostHeader:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "ПРИЗРАК",
                sectionId: self.section
            )
        case .ghostToggle(let value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: "Режим призрака",
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { v in args.toggleGhost(v) }
            )
        case .ghostFooter:
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain("Входящие не помечаются прочитанными. Собеседник не узнает, что вы видели сообщение — даже если вы ответили."),
                sectionId: self.section
            )
        case .statsHeader:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "СТАТИСТИКА",
                sectionId: self.section
            )
        case .statsRow(let total):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: "Мои сообщения",
                label: "\(total)",
                labelStyle: .text,
                sectionId: self.section,
                style: .blocks,
                action: { args.openStats() }
            )
        case .statsFooter:
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain("Статистика отправленных вами сообщений с момента установки eahatgram."),
                sectionId: self.section
            )
        case .visualHeader:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "ВИЗУАЛЬНОЕ",
                sectionId: self.section
            )
        case .visualRow:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: "Визуальное",
                label: "",
                labelStyle: .text,
                sectionId: self.section,
                style: .blocks,
                action: { args.openVisual() }
            )
        case .visualFooter:
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain("NFT подарки и настройка рейтинга профиля."),
                sectionId: self.section
            )
        }
    }
}

private func eahatGramEntries(ghostEnabled: Bool, totalSent: Int) -> [EahatGramEntry] {
    return [
        .ghostHeader,
        .ghostToggle(ghostEnabled),
        .ghostFooter,
        .statsHeader,
        .statsRow(totalSent),
        .statsFooter,
        .visualHeader,
        .visualRow,
        .visualFooter
    ]
}

public func eahatGramController(context: AccountContext) -> ViewController {
    var pushImpl: ((ViewController) -> Void)?

    let arguments = EahatGramArguments(
        context: context,
        toggleGhost: { value in
            let _ = updateExperimentalUISettingsInteractively(
                accountManager: context.sharedContext.accountManager
            ) { settings in
                var s = settings
                s.skipReadHistory = value
                return s
            }.start()
        },
        openStats: {
            pushImpl?(eahatGramStatsController(context: context))
        },
        openVisual: {
            pushImpl?(eahatGramVisualController(context: context))
        }
    )

    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        context.sharedContext.accountManager.sharedData(
            keys: Set([ApplicationSpecificSharedDataKeys.experimentalUISettings])
        )
    )
    |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let experimental: ExperimentalUISettings = sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings]?.get(ExperimentalUISettings.self) ?? .defaultSettings

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("eahatgram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: eahatGramEntries(
                ghostEnabled: experimental.skipReadHistory,
                totalSent: EahatGramStats.shared.totalSent
            ),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)

    pushImpl = { [weak controller] vc in
        controller?.push(vc)
    }

    return controller
}
