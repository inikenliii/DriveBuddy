//
//  AuthenticationViewModel.swift
//  DriveBuddy
//

import Foundation
import CoreData
import SwiftUI
import Combine
import CryptoKit

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String?
    @Published var currentUser: User?
    @Published var currentUserID: String?
    
    let viewContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }

    // MARK: - Sign Up
    func signUp() {
        errorMessage = nil

        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }
        
        guard validateEmail(email) else {
            errorMessage = "Invalid email format."
            return
        }

        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email.lowercased())

        do {
            let users = try viewContext.fetch(request)
            if users.isEmpty {
                let newUser = User(context: viewContext)
                let newUserID = UUID()
                
                newUser.user_id = newUserID
                newUser.email = email.lowercased()
                newUser.password_hash = hash(password)
                newUser.add_to_calendar = false
                newUser.created_at = Date()

                try viewContext.save()

                // Memberikan pesan sukses dan mereset status
                errorMessage = "Registration successful! Please login."
                
                // Reset status login
                currentUser = nil
                isAuthenticated = false
                currentUserID = nil
            } else {
                errorMessage = "Email already registered."
            }
        } catch {
            errorMessage = "Error creating account: \(error.localizedDescription)"
        }
    }


    // MARK: - Login (Perbaikan Utama di sini)
    func login() {
        errorMessage = nil

        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }

        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email.lowercased())

        do {
            // 1. Lakukan fetch. Jika gagal, akan langsung masuk ke block catch.
            let users = try viewContext.fetch(request)

            // 2. Cek apakah ada user yang ditemukan dari hasil fetch.
            if let user = users.first {
                
                // KETIKA USER DITEMUKAN
                
                // 3. Verifikasi password
                if user.password_hash == hash(password) {
                    
                    // PASSWORD COCOK: LOGIN BERHASIL
                    
                    // SET STATUS LOGIN DAN ID PENGGUNA
                    currentUser = user
                    isAuthenticated = true
                    errorMessage = nil
                    currentUserID = user.user_id?.uuidString
                    
                } else {
                    
                    // PASSWORD SALAH
                    errorMessage = "Invalid email or password."
                }
            } else {
                
                // USER TIDAK DITEMUKAN (Email tidak terdaftar)
                errorMessage = "User not found. Please sign up first."
            }
        } catch {
            
            // ERROR TEKNIS (Misalnya Core Data crash/gagal fetch)
            print("Core Data Fetch Error: \(error)") // Untuk tujuan debugging
            errorMessage = "Login failed: An internal error occurred. Please try again later."
        }
    }
    
    // MARK: - Validate Email
    func validateEmail(_ email: String) -> Bool {
            let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
            let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
            return emailPredicate.evaluate(with: email)
        }
    
    // MARK: - Change Password
    func changePassword(
        currentPassword: String,
        newPassword: String,
        confirmPassword: String
    ) -> Bool {
        errorMessage = nil

        guard let user = currentUser else {
            errorMessage = "No user is logged in."
            return false
        }

        // 1. Validasi form
        guard !currentPassword.isEmpty,
              !newPassword.isEmpty,
              !confirmPassword.isEmpty else {
            errorMessage = "Please fill in all fields."
            return false
        }

        // 2. Cek password lama
        let currentHash = hash(currentPassword)
        guard user.password_hash == currentHash else {
            errorMessage = "Current password is incorrect."
            return false
        }

        // 3. Cek konfirmasi password baru
        guard newPassword == confirmPassword else {
            errorMessage = "New password and confirmation do not match."
            return false
        }

        // 4. (Opsional) panjang minimal
        guard newPassword.count >= 6 else {
            errorMessage = "New password must be at least 6 characters."
            return false
        }

        // 5. Simpan password baru
        user.password_hash = hash(newPassword)

        do {
            try viewContext.save()
            // kosongkan field password di VM kalau mau
            password = ""
            return true
        } catch {
            errorMessage = "Failed to update password: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Logout (Diperbaiki)
    func logout() {
        isAuthenticated = false
        currentUser = nil
        currentUserID = nil // Reset ID pengguna saat logout
        email = ""
        password = ""
    }

    // MARK: - Hashing
    private func hash(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
