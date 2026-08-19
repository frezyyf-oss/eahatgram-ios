import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

private enum EahatGramStatsSection: Int32 {
    case totals
    case period
    case week
}

private enum EahatGramStatsEntry: ItemListNodeEntry {
    case totalsHeader
    case totalSent(Int)

    case periodHeader
    case today(Int)
    case thisWeek(Int)
    case thisMonth(Int)

    case weekHeader
    case weekDay(Int, String, Int) // (index, label, count)

    var section: ItemListSectionId {
        switch self {
        case .totalsHeader, .totalSent:
            return EahatGramStatsSection.totals.rawValue
        case .periodHeader, .today, .thisWeek, .thisMonth:
            return EahatGramStatsSection.period.rawValue
        case .weekHeader, .weekDay:
            return EahatGramStatsSection.week.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .totalsHeader:   return 0
        case .totalSent:      return 1
        case .periodHeader:   return 2
        case .today:          return 3
        case .thisWeek:       return 4
        case .thisMonth:      return 5
        case .weekHeader:     return 6
        case .weekDay(let i, _, _): return Int32(7 + i)
        }
    }

    static func < (lhs: EahatGramStatsEntry, rhs: EahatGramStatsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case .totalsHeader:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "ВСЕГО ОТПРАВЛЕНО",
                sectionId: self.section
            )
        case .totalSent(let n):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: "Сообщений",
                label: formatCount(n),
                labelStyle: .text,
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: nil
            )
        case .periodHeader:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "ПЕРИОД",
                sectionId: self.section
            )
        case .today(let n):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: "Сегодня",
                label: formatCount(n),
                labelStyle: .text,
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: nil
            )
        case .thisWeek(let n):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: "На этой неделе",
                label: formatCount(n),
                labelStyle: .text,
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: nil
            )
        case .thisMonth(let n):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: "За 30 дней",
                label: formatCount(n),
                labelStyle: .text,
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: nil
            )
        case .weekHeader:
            return ItemListSectionHeaderItem(
                presentationData: presentationData,
                text: "ПОСЛЕДНИЕ 7 ДНЕЙ",
                sectionId: self.section
            )
        case .weekDay(_, let label, let n):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: label,
                label: formatCount(n),
                labelStyle: n == 0 ? .text : .detailText,
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: nil
            )
        }
    }
}

private func formatCount(_ n: Int) -> String {
    if n >= 1_000_000 {
        return String(format: "%.1fM", Double(n) / 1_000_000)
    } else if n >= 1_000 {
        return String(format: "%.1fK", Double(n) / 1_000)
    }
    return "\(n)"
}

private func eahatGramStatsEntries(stats: EahatGramStats) -> [EahatGramStatsEntry] {
    var entries: [EahatGramStatsEntry] = []

    entries.append(.totalsHeader)
    entries.append(.totalSent(stats.totalSent))

    entries.append(.periodHeader)
    entries.append(.today(stats.sentToday))
    entries.append(.thisWeek(stats.sentThisWeek))
    entries.append(.thisMonth(stats.sentThisMonth))

    let days = stats.lastDays(7)
    entries.append(.weekHeader)
    for (i, day) in days.enumerated() {
        entries.append(.weekDay(i, day.label, day.count))
    }

    return entries
}

public func eahatGramStatsController(context: AccountContext) -> ViewController {
    let signal = context.sharedContext.presentationData
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Статистика"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: eahatGramStatsEntries(stats: EahatGramStats.shared),
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, ()))
    }

    return ItemListController(context: context, state: signal)
}
