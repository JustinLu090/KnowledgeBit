import SwiftUI

// MARK: - FriendItem

struct FriendItem: Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let level: Int
    let avatarURL: URL?
}

// MARK: - AuthService Protocol and Mock

class AuthService: ObservableObject {
    @Published var currentUserId: UUID? = nil
}

class MockAuthService: AuthService {
    override init() {
        super.init()
        self.currentUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
    }
}

// MARK: - FriendService Protocol and Mock

class FriendService {
    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func fetchFriends(currentUserId: UUID) async throws -> [FriendItem] {
        // Mock data
        try await Task.sleep(nanoseconds: 200_000_000)
        return [
            FriendItem(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, displayName: "Alice Anderson", level: 5, avatarURL: nil),
            FriendItem(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, displayName: "Bob Brown", level: 10, avatarURL: nil),
            FriendItem(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, displayName: "Charlie Chaplin", level: 2, avatarURL: nil),
        ]
    }

    func searchUsers(query: String, currentUserId: UUID, excludeUserIds: Set<UUID>) async throws -> [FriendItem] {
        // Mock search: filter from a bigger list
        try await Task.sleep(nanoseconds: 200_000_000)
        let allUsers = [
            FriendItem(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, displayName: "Alice Anderson", level: 5, avatarURL: nil),
            FriendItem(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, displayName: "Bob Brown", level: 10, avatarURL: nil),
            FriendItem(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, displayName: "Charlie Chaplin", level: 2, avatarURL: nil),
            FriendItem(id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!, displayName: "David Dobrik", level: 7, avatarURL: nil),
            FriendItem(id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!, displayName: "Eve Evans", level: 3, avatarURL: nil),
            FriendItem(id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!, displayName: "Frank Foster", level: 8, avatarURL: nil),
        ]
        return allUsers.filter {
            !excludeUserIds.contains($0.id) &&
            $0.displayName.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - InviteFriendsViewModel

@MainActor
class InviteFriendsViewModel: ObservableObject {
    @Published var friends: [FriendItem] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var searchText: String = ""
    @Published var selected: Set<UUID> = []

    private let auth: AuthService
    private let service: FriendService

    private var searchTask: Task<Void, Never>?

    init(auth: AuthService) {
        self.auth = auth
        self.service = FriendService(authService: auth)
    }

    func loadFriends() async {
        guard let currentUserId = auth.currentUserId else {
            error = "User not logged in"
            return
        }
        isLoading = true
        error = nil
        do {
            let fetched = try await service.fetchFriends(currentUserId: currentUserId)
            friends = fetched
        } catch {
            self.error = error.localizedDescription
            friends = []
        }
        isLoading = false
    }

    func search() async {
        guard let currentUserId = auth.currentUserId else {
            error = "User not logged in"
            return
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            await loadFriends()
            return
        }

        isLoading = true
        error = nil
        do {
            let excludeIds = Set([currentUserId])
            let results = try await service.searchUsers(query: query, currentUserId: currentUserId, excludeUserIds: excludeIds)
            friends = results
        } catch {
            self.error = error.localizedDescription
            friends = []
        }
        isLoading = false
    }

    func toggleSelect(_ id: UUID) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    func applyPreselected(_ ids: [UUID]) {
        selected = Set(ids)
    }
}

// MARK: - InviteFriendsSheet View

struct InviteFriendsSheet: View {
    @EnvironmentObject private var auth: AuthService
    @StateObject private var vm: InviteFriendsViewModel

    private let onDone: ([UUID]) -> Void
    private let onCancel: () -> Void
    private let preselected: [UUID]

    @State private var debounceToken = UUID()

    init(preselected: [UUID] = [],
         onDone: @escaping ([UUID]) -> Void,
         onCancel: @escaping () -> Void) {
        self.preselected = preselected
        self.onDone = onDone
        self.onCancel = onCancel
        // vm must be created after auth environment injected, so created in body
        _vm = StateObject(wrappedValue: InviteFriendsViewModel(auth: AuthService()))
    }

    var body: some View {
        NavigationStack {
            List(vm.friends) { friend in
                Button(action: {
                    vm.toggleSelect(friend.id)
                }) {
                    HStack(spacing: 12) {
                        AvatarView(name: friend.displayName, url: friend.avatarURL)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        VStack(alignment: .leading) {
                            Text(friend.displayName)
                                .font(.body)
                            Text("Level \(friend.level)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if vm.selected.contains(friend.id) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .disabled(vm.isLoading)
            .searchable(text: $vm.searchText)
            .onChange(of: vm.searchText) { newValue in
                debounceToken = UUID()
                let currentToken = debounceToken
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if debounceToken == currentToken {
                        Task {
                            await vm.search()
                        }
                    }
                }
            }
            .navigationTitle("Invite Friends")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(Array(vm.selected))
                    }
                    .disabled(vm.selected.isEmpty)
                }
            }
            .overlay {
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.15))
                }
            }
            .task {
                vm.applyPreselected(preselected)
                await vm.loadFriends()
            }
            .onAppear {
                // Replace vm's auth with environmentObject auth to ensure proper currentUserId
                vm.applyPreselected(preselected)
            }
        }
        .environmentObject(auth)
        .onAppear {
            // Re-create vm with proper auth from environment if needed
            if vm.auth !== auth {
                vm.applyPreselected(preselected)
            }
        }
        .onChange(of: auth.currentUserId) { _ in
            Task {
                await vm.loadFriends()
            }
        }
    }
}

// MARK: - AvatarView Helper

struct AvatarView: View {
    let name: String
    let url: URL?

    var body: some View {
        if let url = url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackView
                @unknown default:
                    fallbackView
                }
            }
        } else {
            fallbackView
        }
    }

    private var fallbackView: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.3))
            .overlay(
                Text(initials(for: name))
                    .font(.headline)
                    .foregroundColor(.white)
            )
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let firstInitial = parts.first?.prefix(1) ?? ""
        let secondInitial = parts.count > 1 ? parts[1].prefix(1) : ""
        return (firstInitial + secondInitial).uppercased()
    }
}

// MARK: - Preview

struct InviteFriendsSheet_Previews: PreviewProvider {
    static var previews: some View {
        InviteFriendsSheet(preselected: []) { selectedIds in
            // Done action
        } onCancel: {
            // Cancel action
        }
        .environmentObject(MockAuthService())
    }
}
