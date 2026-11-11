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
import WeatherDisplay

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
            .refreshable { await viewModel.onRefresh() }
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

    /// A card whose weather is older than this says how old it is.
    private static let staleAge: TimeInterval = 60 * 60

    var body: some View {
        HStack(alignment: .top, spacing: .m) {
            VStack(alignment: .leading, spacing: .xxs) {
                Text(card.name)
                    .textStyle(.title, color: foreground)
                    .lineLimit(1)
                subtitle
                Spacer(minLength: .s)
                footnote
            }
            Spacer(minLength: 0)
            if let weather = card.weather {
                VStack(alignment: .trailing, spacing: .xxs) {
                    Text(weather.temperature)
                        .font(TextStyle.cardTemperature.font)
                        .foregroundStyle(foreground)
                        .monospacedDigit()
                    Spacer(minLength: .s)
                    Text(weather.highLow)
                        .textStyle(.callout, color: foreground)
                        .monospacedDigit()
                }
            }
        }
        .padding(.m)
        .frame(maxWidth: .infinity, minHeight: RowHeight.card, alignment: .topLeading)
        .background(background, in: .rect(cornerRadius: Radius.card))
        .shadow(color: DesignTokens.softShadow, radius: .s, y: .xxs)
        .contentShape(.rect(cornerRadius: Radius.card))
    }

    private var background: Color {
        card.weather.map { $0.weatherCode.background(isDay: $0.isDay) } ?? DesignTokens.groupedBackground
    }

    private var foreground: Color {
        card.weather == nil ? DesignTokens.primaryText : ConditionPalette.foreground
    }

    private var secondaryForeground: Color {
        card.weather == nil ? DesignTokens.secondaryText : ConditionPalette.secondaryForeground
    }

    @ViewBuilder
    private var subtitle: some View {
        if card.isCurrentLocation {
            HStack(spacing: .xs) {
                Image(systemSymbol: .locationFill)
                    .imageScale(.small)
                Text(String.PlacesUI.placesMyLocation)
            }
            .textStyle(.callout, color: card.weather == nil ? DesignTokens.accent : foreground)
        } else if let timeZone = card.timeZone {
            TimelineView(.everyMinute) { context in
                Text(context.date, format: .dateTime.hour().minute())
                    .textStyle(.callout, color: foreground)
                    // Text applies the environment's time zone to a date
                    // format, overriding any zone set on the format itself.
                    .environment(\.timeZone, timeZone)
            }
        }
    }

    /// The condition, or how old the weather is once that's worth saying.
    @ViewBuilder
    private var footnote: some View {
        if let weather = card.weather {
            TimelineView(.everyMinute) { context in
                if context.date.timeIntervalSince(weather.updatedAt) > Self.staleAge {
                    Text(String.PlacesUI.placesUpdated(weather.updatedAt.formatted(.relative(presentation: .named))))
                        .textStyle(.callout, color: secondaryForeground)
                } else {
                    Text(weather.condition)
                        .textStyle(.callout, color: secondaryForeground)
                }
            }
            .lineLimit(1)
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
