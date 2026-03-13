import SwiftUI

struct PhoneEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phone = ""
    @State private var sent = false
    @State private var code = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    let onComplete: (Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                if !sent {
                    Section {
                        TextField("Phone (e.g. +15551234567)", text: $phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                    }
                    if let msg = errorMessage {
                        Section {
                            Text(msg).foregroundStyle(.red)
                        }
                    }
                } else {
                    Section {
                        TextField("Enter 6-digit code", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .autocorrectionDisabled()
                    }
                    if let msg = errorMessage {
                        Section {
                            Text(msg).foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(sent ? "Enter code" : "Phone number")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onComplete(false)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if sent {
                        Button("Verify") { verifyCode() }
                            .disabled(code.count < 4 || isLoading)
                    } else {
                        Button("Send code") { requestCode() }
                            .disabled(phone.count < 10 || isLoading)
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }

    private func requestCode() {
        errorMessage = nil
        guard phone.hasPrefix("+") else {
            errorMessage = "Use E.164 format (e.g. +15551234567)"
            return
        }
        Task {
            await doRequestCode()
        }
    }

    private func doRequestCode() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let client = APIClient(token: nil)
            let body = PhoneRequestRequest(phone: phone)
            _ = try await client.post("/api/v1/auth/phone/request", body: body) as PhoneRequestResponse
            await MainActor.run { sent = true }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to send code. Check number and try again."
            }
        }
    }

    private func verifyCode() {
        errorMessage = nil
        Task {
            await doVerifyCode()
        }
    }

    private func doVerifyCode() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let client = APIClient(token: nil)
            let body = PhoneVerifyRequest(phone: phone, code: code)
            let response: AuthResponse = try await client.post("/api/v1/auth/phone/verify", body: body)
            KeychainService.saveToken(response.accessToken)
            await MainActor.run {
                onComplete(true)
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Invalid or expired code."
            }
        }
    }
}
