//
//  Feed View (new).swift
//  Mlem
//
//  Created by Eric Andrews on 2023-07-21.
//

import Foundation
import SwiftUI
import Dependencies

struct FeedView: View {
    
    // MARK: Environment and settings
    
    @Dependency(\.hapticManager) var hapticManager
    
    @AppStorage("shouldShowCommunityHeaders") var shouldShowCommunityHeaders: Bool = false
    @AppStorage("shouldBlurNsfw") var shouldBlurNsfw: Bool = true
    @AppStorage("defaultPostSorting") var defaultPostSorting: PostSortType = .hot
    @AppStorage("shouldShowPostCreator") var shouldShowPostCreator: Bool = true
    @AppStorage("postSize") var postSize: PostSize = .large
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var filtersTracker: FiltersTracker
    @EnvironmentObject var favoriteCommunitiesTracker: FavoriteCommunitiesTracker
    @EnvironmentObject var editorTracker: EditorTracker
    
    // MARK: Parameters and init
    
    let community: APICommunity?
    let showLoading: Bool
    @State var feedType: FeedType
    
    init(community: APICommunity?, feedType: FeedType, showLoading: Bool = false) {
        self.community = community
        self.showLoading = showLoading
        self._feedType = State(initialValue: feedType)
    }
    
    // MARK: State
    
    @StateObject var postTracker: PostTracker = .init(shouldPerformMergeSorting: false)
    
    @State var communityDetails: GetCommunityResponse?
    @State var postSortType: PostSortType = .hot
    @State var isLoading: Bool = false
    
    // MARK: - Main Views
    
    var body: some View {
        contentView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondarySystemBackground)
            .toolbar {
                ToolbarItem(placement: .principal) { toolbarHeader }
                ToolbarItem(placement: .navigationBarTrailing) { sortMenu }
                ToolbarItemGroup(placement: .navigationBarTrailing) { ellipsisMenu }
            }
            .navigationBarTitleDisplayMode(.inline)
            .environmentObject(postTracker)
            .task(priority: .userInitiated) { await initFeed() }
            .task(priority: .background) { await fetchCommunityDetails() }
        // using hardRefreshFeed() for these three so that the user gets immediate feedback, also kills the ScrollViewReader
            .onChange(of: feedType) { _ in
                hardRefreshFeed()
            }
            .onChange(of: postSortType) { _ in
                hardRefreshFeed()
            }
            .onChange(of: appState.currentActiveAccount) { _ in
                hardRefreshFeed()
            }
            .refreshable { await refreshFeed() }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            if postTracker.items.isEmpty {
                noPostsView()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(postTracker.items) { postView in
                        feedPost(for: postView)
                    }
                    
                    EndOfFeedView(isLoading: isLoading)
                }
            }
        }
        .fancyTabScrollCompatible()
    }
    
    @ViewBuilder
    private func noPostsView() -> some View {
        if isLoading {
            LoadingView(whatIsLoading: .posts)
        } else {
            VStack(alignment: .center, spacing: 5) {
                Image(systemName: "text.bubble")
                
                Text("No posts to be found")
            }
            .padding()
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: Helper Views
    
    @ViewBuilder
    private func feedPost(for postView: APIPostView) -> some View {
        VStack(spacing: 0) {
            NavigationLink(value: PostLinkWithContext(post: postView, postTracker: postTracker)) {
                FeedPost(
                    postView: postView,
                    showPostCreator: shouldShowPostCreator,
                    showCommunity: community == nil)
            }
            Divider()
        }
        .buttonStyle(EmptyButtonStyle()) // Make it so that the link doesn't mess with the styling
        .task(priority: .medium) {
            if postTracker.shouldLoadContent(after: postView) {
                await loadFeed()
            }
        }
    }
    
    @ViewBuilder
    private var ellipsisMenu: some View {
        Menu {
            if let community, let communityDetails {
                // until we find a nice way to put nav stuff in MenuFunction, this'll have to do :(
                NavigationLink(value:
                                CommunitySidebarLinkWithContext(
                                    community: community,
                                    communityDetails: communityDetails
                                )) {
                                    Label("Sidebar", systemImage: "sidebar.right")
                                }
                
                ForEach(genCommunitySpecificMenuFunctions(for: community)) { menuFunction in
                    MenuButton(menuFunction: menuFunction)
                }
            }
            
            Divider()
            
            ForEach(genEllipsisMenuFunctions()) { menuFunction in
                MenuButton(menuFunction: menuFunction)
            }
            
            Menu {
                ForEach(genPostSizeSwitchingFunctions()) { menuFunction in
                    MenuButton(menuFunction: menuFunction)
                }
            } label: {
                Label("Post Size", systemImage: AppConstants.postSizeSettingsSymbolName)
            }
        } label: {
            Label("More", systemImage: "ellipsis")
                .frame(height: AppConstants.barIconHitbox)
                .contentShape(Rectangle())
        }
    }
    
    @ViewBuilder
    private var sortMenu: some View {
        Menu {
            ForEach(genOuterSortMenuFunctions()) { menuFunction in
                MenuButton(menuFunction: menuFunction)
            }
            
            Menu {
                ForEach(genTopSortMenuFunctions()) { menuFunction in
                    MenuButton(menuFunction: menuFunction)
                }
            } label: {
                Label("Top...", systemImage: AppConstants.topSymbolName)
            }
        } label: {
            Label("Selected sorting by \(postSortType.description)",
                  systemImage: postSortType.iconName)
        }
    }
    
    @ViewBuilder
    private var toolbarHeader: some View {
        if let community = community {
            NavigationLink(value:
                            CommunitySidebarLinkWithContext(
                                community: community,
                                communityDetails: communityDetails
                            )) {
                                Text(community.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .accessibilityHint("Activate to view sidebar.")
                            }
        } else {
            Menu {
                ForEach(genFeedSwitchingFunctions()) { menuFunction in
                    MenuButton(menuFunction: menuFunction)
                }
            } label: {
                HStack(alignment: .center, spacing: 0) {
                    Text(feedType.label)
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .scaleEffect(0.7)
                }
                .foregroundColor(.primary)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Activate to change feeds.")
                // this disables the implicit animation on the header view...
                .transaction { $0.animation = nil }
            }
        }
    }
}