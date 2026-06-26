import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - User Role

enum UserRole: String, Codable, CaseIterable {
    case admin      = "admin"
    case customer   = "customer"
    case doorStaff  = "doorStaff"
    case dj         = "dj"

    var displayName: String {
        switch self {
        case .admin:     return "Admin"
        case .customer:  return "Customer"
        case .doorStaff: return "Door Staff"
        case .dj:        return "DJ"
        }
    }

    var icon: String {
        switch self {
        case .admin:     return "crown.fill"
        case .customer:  return "person.fill"
        case .doorStaff: return "door.left.hand.open"
        case .dj:        return "music.note"
        }
    }
}

// MARK: - Database User Profile

struct DBUser: Identifiable, Codable {
    let id: String          // Firebase Auth UID
    var firstName: String
    var lastName: String
    var email: String
    var phone: String
    var dob: String?        // ISO "yyyy-MM-dd" — for co-brand API
    var role: UserRole
    var createdAt: Date

    var fullName: String { "\(firstName) \(lastName)" }

    enum CodingKeys: String, CodingKey {
        case id, firstName, lastName, email, phone, dob, role, createdAt
    }
}

// MARK: - Auth Service

final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: DBUser?
    @Published var isAuthenticated = false
    @Published var isLoading = true

    private let db = Firestore.firestore()
    private var authListener: AuthStateDidChangeListenerHandle?

    private init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self else { return }
            if let firebaseUser {
                Task {
                    await self.fetchUserProfile(uid: firebaseUser.uid)
                }
            } else {
                DispatchQueue.main.async {
                    self.currentUser = nil
                    self.isAuthenticated = false
                    self.isLoading = false
                }
            }
        }
    }

    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Auth Actions

    func login(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        await fetchUserProfile(uid: result.user.uid)
    }

    func register(firstName: String, lastName: String, email: String, password: String, phone: String, dob: String? = nil) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = result.user.uid

        let snapshot = try await db.collection("users").getDocuments()
        let role: UserRole = snapshot.documents.isEmpty ? .admin : .customer

        let user = DBUser(
            id: uid,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            dob: dob,
            role: role,
            createdAt: Date()
        )
        try await saveUserProfile(user)
        DispatchQueue.main.async {
            self.currentUser = user
            self.isAuthenticated = true
            self.isLoading = false
        }
    }

    func logout() throws {
        try Auth.auth().signOut()
        DispatchQueue.main.async {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }

    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    // MARK: - Profile

    @MainActor
    private func fetchUserProfile(uid: String) async {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            if let user = try? doc.data(as: DBUser.self) {
                self.currentUser = user
                self.isAuthenticated = true
            } else {
                // Profile missing — sign out
                try? Auth.auth().signOut()
                self.isAuthenticated = false
            }
        } catch {
            print("❌ fetchUserProfile: \(error)")
            self.isAuthenticated = false
        }
        self.isLoading = false
    }

    func saveUserProfile(_ user: DBUser) async throws {
        try db.collection("users").document(user.id).setData(from: user)
    }

    // MARK: - Admin: fetch all users

    func fetchAllUsers() async throws -> [DBUser] {
        let snapshot = try await db.collection("users").order(by: "createdAt", descending: false).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: DBUser.self) }
    }

    // MARK: - Admin: update role

    func updateRole(userId: String, role: UserRole) async throws {
        try await db.collection("users").document(userId).updateData(["role": role.rawValue])
        // Refresh current user if they updated themselves
        if currentUser?.id == userId {
            currentUser?.role = role
        }
    }
}
