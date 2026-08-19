import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class EahatGramVisualArguments {
    let openNFT: () -> Void
    let openRating: () -> Void

    init(openNFT: @escaping () -> Void, openRating: @escaping () -> Void) {
        self.openNFT = openNFT
        self.openRating = openRating
    }
}

private enum EahatGramVisualSection: Int32 {
    case nft
    case rating
}

private enum EahatGramVisualEntry: ItemListNodeEntry {
    case nftHeader
    case nftRow
    case nftFooter
    case ratingHeader
    case ratingRow
    case ratingFooter

    var section: ItemListSectionId {
        switch self {
        case .nftHeader, .nftRow, .nftFooter:
            return EahatGramVisualSection.nft.rawValue
        case .ratingHeader, .ratingRow, .ratingFooter:
            return EahatGramVisualSection.rating.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .nftHeader:    return 0
        case .nftRow:       return 1
        case .nftFooter:    return 2
        case .ratingHeader: return 3
        case .ratingRow:    return 4
        case .ratingFooter: return 5
        }
    }

    static func < (lhs: EahatGramVisualEntry, rhs: EahatGramVisualEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! EahatGramVisualArguments
        switch self {
        case .nftHeader:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "NFT ПОДАРКИ",
                sectionId: self.section
            )
        case .nftRow:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: "Мои и все NFT подарки",
                label: "",
                labelStyle: .text,
                sectionId: self.section,
                style: .blocks,
                action: { args.openNFT() }
            )
        case .nftFooter:
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain("Просматривай все доступные подарки и управляй тем, какие отображаются на твоём профиле."),
                sectionId: self.section
            )
        case .ratingHeader:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "РЕЙТИНГ",
                sectionId: self.section
            )
        case .ratingRow:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: "Рейтинг и уровень",
                label: "",
                labelStyle: .text,
                sectionId: self.section,
                style: .blocks,
                action: { args.openRating() }
            )
        case .ratingFooter:
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain("Установи свой уровень и количество звёзд — изменения сразу применятся к твоему профилю."),
                sectionId: self.section
            )
        }
    }
}

public func eahatGramVisualController(context: AccountContext) -> ViewController {
    var pushImpl: ((ViewController) -> Void)?

    let arguments = EahatGramVisualArguments(
        openNFT: { pushImpl?(eahatGramNFTController(context: context)) },
        openRating: { pushImpl?(eahatGramRatingController(context: context)) }
    )

    let signal = context.sharedContext.presentationData
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Визуальное"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let entries: [EahatGramVisualEntry] = [
            .nftHeader, .nftRow, .nftFooter,
            .ratingHeader, .ratingRow, .ratingFooter
        ]
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushImpl = { [weak controller] vc in controller?.push(vc) }
    return controller
}
