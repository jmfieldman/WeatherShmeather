//
//  PlacesListView.swift
//  Copyright © 2026 WeatherShmeather.
//

import DesignSystem
import PlacesManager
import PlacesUIResources
import SFSafeSymbols
import SwiftAsyncEx
import SwiftUI
import SwiftUIEx

public struct PlacesListView: HostedView {
    @Bindable var viewModel: PlacesListViewModel
    @FocusState private var isSearchFieldFocused: Bool

    public init(viewModel: PlacesListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            DesignTokens.screenBackground.ignoresSafeArea()

            if viewModel.isSearching {
                SearchResultsView(viewModel: viewModel)
            } else if viewModel.showsEmptyState {
                EmptyPlacesView()
            } else {
                cardList
            }
        }
        .safeAreaInset(edge: .bottom) {
            searchBar
        }
        .onChange(of: isSearchFieldFocused) { _, isFocused in
            if isFocused, !viewModel.isSearching {
                viewModel.beginSearch()
            }
        }
        .onChange(of: viewModel.isSearching) { _, isSearching in
            if !isSearching {
                isSearchFieldFocused = false
            }
        }
    }

    // MARK: Cards

    private var cardList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(viewModel.cards) { card in
                    Button {
                        viewModel.onSelectCard(card.id)
                    } label: {
                        PlaceCardView(card: card)
                    }
                    .buttonStyle(.plain)
                    .id(card.id)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: .xs, leading: .gutter, bottom: .xs, trailing: .gutter))
                    .deleteDisabled(card.isCurrentLocation)
                    .moveDisabled(card.isCurrentLocation)
                }
                .onDelete { viewModel.deleteCards(atOffsets: $0) }
                .onMove { viewModel.moveCards(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(viewModel.isEditing ? .active : .inactive))
            .animation(.default, value: viewModel.cards)
            .onChange(of: viewModel.cards) { scrollToTarget(with: proxy) }
            .onChange(of: viewModel.scrollTarget) { scrollToTarget(with: proxy) }
        }
    }

    /// The target may arrive before its card does, so this runs on both changes.
    private func scrollToTarget(with proxy: ScrollViewProxy) {
        guard let target = viewModel.scrollTarget, viewModel.cards.contains(where: { $0.id == target }) else {
            return
        }

        withAnimation {
            proxy.scrollTo(target, anchor: .center)
        }
        viewModel.scrollTarget = nil
    }

    // MARK: Search bar

    private var searchBar: some View {
        GlassEffectContainer(spacing: .s) {
            HStack(spacing: .s) {
                HStack(spacing: .s) {
                    Image(systemSymbol: .magnifyingglass)
                        .foregroundStyle(DesignTokens.secondaryText)
                    TextField(String.PlacesUI.placesSearchPlaceholder, text: $viewModel.searchText)
                        .textStyle(.body)
                        .focused($isSearchFieldFocused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemSymbol: .xmarkCircleFill)
                                .foregroundStyle(DesignTokens.tertiaryText)
                        }
                        .accessibilityLabel(String.PlacesUI.placesSearchClear)
                    }
                }
                .padding(.horizontal, .m)
                .frame(minHeight: ControlHeight.primary)
                .glassEffect(.regular.interactive(), in: .capsule)

                if viewModel.isSearching {
                    Button {
                        viewModel.endSearch()
                    } label: {
                        Image(systemSymbol: .xmark)
                            .font(TextStyle.headline.font)
                            .foregroundStyle(DesignTokens.primaryText)
                            .frame(width: ControlHeight.primary, height: ControlHeight.primary)
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel(String.PlacesUI.placesSearchClose)
                }
            }
        }
        .padding(.horizontal, .gutter)
        .padding(.bottom, .s)
        .animation(.default, value: viewModel.isSearching)
    }
}

// MARK: - Card

struct PlaceCardView: View {
    let card: PlaceCard

    var body: some View {
        HStack(alignment: .top, spacing: .m) {
            VStack(alignment: .leading, spacing: .xs) {
                Text(card.name)
                    .textStyle(.title)
                    .lineLimit(1)
                subtitle
            }
            Spacer(minLength: 0)
        }
        .padding(.m)
        .frame(maxWidth: .infinity, minHeight: RowHeight.card, alignment: .topLeading)
        .background(DesignTokens.groupedBackground, in: .rect(cornerRadius: Radius.card))
        .shadow(color: DesignTokens.softShadow, radius: .s, y: .xxs)
        .contentShape(.rect(cornerRadius: Radius.card))
    }

    @ViewBuilder
    private var subtitle: some View {
        if card.isCurrentLocation {
            HStack(spacing: .xs) {
                Image(systemSymbol: .locationFill)
                    .imageScale(.small)
                Text(String.PlacesUI.placesMyLocation)
            }
            .textStyle(.callout, color: DesignTokens.accent)
        } else if let timeZone = card.timeZone {
            TimelineView(.everyMinute) { context in
                Text(context.date, format: .dateTime.hour().minute())
                    .textStyle(.callout, color: DesignTokens.secondaryText)
                    // Text applies the environment's time zone to a date
                    // format, overriding any zone set on the format itself.
                    .environment(\.timeZone, timeZone)
            }
        }
    }
}

// MARK: - Search results

struct SearchResultsView: View {
    let viewModel: PlacesListViewModel

    var body: some View {
        switch viewModel.searchState {
        case .idle:
            Color.clear

        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .noResults(query):
            message(String.PlacesUI.placesSearchNoResults(query))

        case let .failed(text):
            message(text)

        case let .results(rows):
            List(rows) { row in
                SearchRowView(row: row, task: viewModel.addTask)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .textStyle(.callout, color: DesignTokens.secondaryText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, .gutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchRowView: View {
    let row: SearchRow
    let task: SerialTask<PlaceSearchResult, Void>

    var body: some View {
        Button {
            task.fire(row.result)
        } label: {
            HStack(spacing: .s) {
                Text("\(Text(row.result.name).foregroundStyle(DesignTokens.primaryText))  \(Text(row.result.detail).foregroundStyle(DesignTokens.secondaryText))")
                    .font(TextStyle.body.font)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if row.isSaved {
                    Image(systemSymbol: .checkmark)
                        .foregroundStyle(DesignTokens.accent)
                        .accessibilityLabel(String.PlacesUI.placesSearchSaved)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(row.isSaved || task.isExecuting)
    }
}

// MARK: - Empty state

struct EmptyPlacesView: View {
    var body: some View {
        VStack(spacing: .m) {
            Image(systemSymbol: .mapFill)
                .font(TextStyle.display.font)
                .foregroundStyle(DesignTokens.symbolCloud)
                .accessibilityHidden(true)
            Text(String.PlacesUI.placesEmptyTitle)
                .textStyle(.title)
            Text(String.PlacesUI.placesEmptyBody)
                .textStyle(.callout, color: DesignTokens.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, .xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

private extension PlacesListViewModel {
    static func preview(cards: [PlaceCard]) -> PlacesListViewModel {
        PlacesListViewModel(cards: cards, hasLoaded: true, addTask: SerialTask { _ in })
    }

    static let previewCards = [
        PlaceCard(id: "here", name: "Tarzana", isCurrentLocation: true, timeZone: nil),
        PlaceCard(id: "a", name: "Palm Desert", isCurrentLocation: false, timeZone: TimeZone(identifier: "America/Los_Angeles")),
        PlaceCard(id: "b", name: "Edgartown", isCurrentLocation: false, timeZone: TimeZone(identifier: "America/New_York")),
    ]
}

#Preview("Light") {
    PlacesListView(viewModel: .preview(cards: PlacesListViewModel.previewCards))
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    PlacesListView(viewModel: .preview(cards: PlacesListViewModel.previewCards))
        .preferredColorScheme(.dark)
}

#Preview("Empty") {
    PlacesListView(viewModel: .preview(cards: []))
}
