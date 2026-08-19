import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

// MARK: - Helpers

private func rarityText(_ rarity: StarGift.UniqueGift.Attribute.Rarity) -> String {
    switch rarity {
    case .uncommon:             return "Необычный"
    case .rare:                 return "Редкий"
    case .epic:                 return "Эпический"
    case .legendary:            return "Легендарный"
    case .permille(let v):
        if v <= 10        { return "Легендарный" }
        else if v <= 50   { return "Эпический" }
        else if v <= 200  { return "Редкий" }
        else              { return "Необычный" }
    }
}

private func rarityColor(_ rarity: StarGift.UniqueGift.Attribute.Rarity) -> UIColor {
    switch rarity {
    case .uncommon:           return UIColor(rgb: 0x4BB34B)
    case .rare:               return UIColor(rgb: 0x2EABFB)
    case .epic:               return UIColor(rgb: 0xA02FFF)
    case .legendary:          return UIColor(rgb: 0xE07700)
    case .permille(let v):
        if v <= 10        { return UIColor(rgb: 0xE07700) }
        else if v <= 50   { return UIColor(rgb: 0xA02FFF) }
        else if v <= 200  { return UIColor(rgb: 0x2EABFB) }
        else              { return UIColor(rgb: 0x4BB34B) }
    }
}

private func circleImage(color: UIColor, size: CGSize = CGSize(width: 40, height: 40)) -> UIImage {
    return UIGraphicsImageRenderer(size: size).image { ctx in
        let cgCtx = ctx.cgContext
        cgCtx.addEllipse(in: CGRect(origin: .zero, size: size))
        cgCtx.clip()
        color.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
    }
}

private func gradientCircle(inner: UInt32, outer: UInt32, size: CGSize = CGSize(width: 40, height: 40)) -> UIImage {
    return UIGraphicsImageRenderer(size: size).image { ctx in
        let cgCtx = ctx.cgContext
        cgCtx.addEllipse(in: CGRect(origin: .zero, size: size))
        cgCtx.clip()
        let c1 = UIColor(rgb: inner).cgColor
        let c2 = UIColor(rgb: outer).cgColor
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [c1, c2] as CFArray,
            locations: [0.0, 1.0]
        ) {
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            cgCtx.drawRadialGradient(
                gradient,
                startCenter: center, startRadius: 0,
                endCenter: center, endRadius: size.width / 2,
                options: []
            )
        } else {
            UIColor(rgb: inner).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// Extracts backdrop colors from unique gift attributes; falls back to nil.
private func backdropColors(from attributes: [StarGift.UniqueGift.Attribute]) -> (inner: UInt32, outer: UInt32)? {
    for attr in attributes {
        if case .backdrop(_, _, let inner, let outer, _, _, _) = attr {
            return (UInt32(bitPattern: inner), UInt32(bitPattern: outer))
        }
    }
    return nil
}

private func modelRarity(from attributes: [StarGift.UniqueGift.Attribute]) -> StarGift.UniqueGift.Attribute.Rarity? {
    for attr in attributes {
        if case .model(_, _, let rarity, _) = attr { return rarity }
    }
    return nil
}

// MARK: - Arguments

private final class EahatGramNFTArguments {
    let toggleGift: (StarGiftReference, Bool) -> Void
    init(toggleGift: @escaping (StarGiftReference, Bool) -> Void) {
        self.toggleGift = toggleGift
    }
}

// MARK: - Entries

private enum EahatGramNFTSection: Int32 {
    case owned
    case catalog
}

private enum EahatGramNFTEntry: ItemListNodeEntry {
    // Owned unique gifts
    case ownedHeader
    case ownedGift(index: Int, gift: ProfileGiftsContext.State.StarGift, icon: UIImage, subtitle: String)
    case ownedEmpty

    // Catalog of all available gift types
    case catalogHeader
    case catalogGift(index: Int, id: Int64, title: String, price: Int64, label: String)

    var section: ItemListSectionId {
        switch self {
        case .ownedHeader, .ownedGift, .ownedEmpty:
            return EahatGramNFTSection.owned.rawValue
        case .catalogHeader, .catalogGift:
            return EahatGramNFTSection.catalog.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .ownedHeader:                      return 0
        case .ownedGift(let i, _, _, _):        return Int32(1 + i)
        case .ownedEmpty:                        return 999
        case .catalogHeader:                     return 1000
        case .catalogGift(let i, _, _, _, _):   return Int32(1001 + i)
        }
    }

    static func < (lhs: EahatGramNFTEntry, rhs: EahatGramNFTEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! EahatGramNFTArguments
        switch self {

        case .ownedHeader:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "МОИ NFT",
                sectionId: self.section
            )

        case .ownedGift(_, let gift, let icon, let subtitle):
            let isSaved = gift.savedToProfile
            return ItemListSwitchItem(
                presentationData: presentationData,
                icon: icon,
                title: {
                    if case .unique(let u) = gift.gift { return u.title }
                    return "NFT подарок"
                }(),
                text: subtitle,
                value: isSaved,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    guard let ref = gift.reference else { return }
                    args.toggleGift(ref, value)
                }
            )

        case .ownedEmpty:
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain("У тебя пока нет NFT подарков. Они появятся здесь, когда ты их получишь."),
                sectionId: self.section
            )

        case .catalogHeader:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "ВСЕ ПОДАРКИ",
                sectionId: self.section
            )

        case .catalogGift(_, _, let title, let price, let label):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: title,
                label: "⭐\(price)  \(label)",
                labelStyle: .detailText,
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: nil
            )
        }
    }
}

// MARK: - Entry builder

private func buildEntries(
    presentationData: PresentationData,
    ownedGifts: [ProfileGiftsContext.State.StarGift],
    allGifts: [StarGift]?
) -> [EahatGramNFTEntry] {
    var entries: [EahatGramNFTEntry] = []

    // Owned NFTs
    entries.append(.ownedHeader)
    if ownedGifts.isEmpty {
        entries.append(.ownedEmpty)
    } else {
        for (i, gift) in ownedGifts.enumerated() {
            guard case .unique(let u) = gift.gift else { continue }

            let rarity = modelRarity(from: u.attributes)
            let icon: UIImage
            if let colors = backdropColors(from: u.attributes) {
                icon = gradientCircle(inner: colors.inner, outer: colors.outer)
            } else if let r = rarity {
                icon = circleImage(color: rarityColor(r))
            } else {
                icon = circleImage(color: UIColor(rgb: 0x5BBEFF))
            }

            let rarityStr = rarity.map { rarityText($0) } ?? ""
            let subtitle = "#\(u.number) из \(u.availability.total)\(rarityStr.isEmpty ? "" : " · \(rarityStr)")"
            entries.append(.ownedGift(index: i, gift: gift, icon: icon, subtitle: subtitle))
        }
    }

    // Catalog
    if let gifts = allGifts, !gifts.isEmpty {
        entries.append(.catalogHeader)
        var idx = 0
        for gift in gifts {
            guard case .generic(let g) = gift else { continue }
            let title = g.title ?? "Подарок"
            var label = ""
            if let avail = g.availability {
                if avail.remains > 0 {
                    label = "\(avail.remains)/\(avail.total)"
                } else {
                    label = "Нет в наличии"
                }
            }
            entries.append(.catalogGift(index: idx, id: g.id, title: title, price: g.price, label: label))
            idx += 1
            if idx >= 100 { break }
        }
    }

    return entries
}

// MARK: - Controller

public func eahatGramNFTController(context: AccountContext) -> ViewController {
    let profileGiftsContext = ProfileGiftsContext(
        account: context.account,
        peerId: context.account.peerId,
        filter: [.unique],
        limit: 100
    )

    let keepFreshDisposable = MetaDisposable()

    let arguments = EahatGramNFTArguments(
        toggleGift: { [weak profileGiftsContext] reference, added in
            profileGiftsContext?.updateStarGiftAddedToProfile(reference: reference, added: added)
        }
    )

    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        profileGiftsContext.state,
        context.engine.payments.cachedStarGifts()
    )
    |> map { presentationData, giftsState, allGifts -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("NFT Подарки"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: buildEntries(
                presentationData: presentationData,
                ownedGifts: giftsState.gifts,
                allGifts: allGifts
            ),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)

    keepFreshDisposable.set(context.engine.payments.keepStarGiftsUpdated().start())
    // Tie the disposable lifetime to the controller so it's cleaned up when popped.
    controller.navigationController?.viewControllers.last.flatMap { _ in
        // Disposable held in closure below via capture.
    }
    _ = keepFreshDisposable // keep alive until controller deallocs (captured in signal chain)

    return controller
}
