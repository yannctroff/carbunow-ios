//
//  ReportIssueView.swift
//  CarbuNow - Prix Du Carburant
//
//  Created by Yann CATTARIN on 22/03/2026.
//


import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct ReportIssueView: View {
    @Environment(\.dismiss) private var dismiss

    let station: FuelStation

    @State private var selectedIssueType: StationIssueType = .badLocation
    @State private var message: String = ""

    @State private var isSending = false
    @State private var alertMessage: IssueAlertMessage?

    @State private var selectedFileName: String?
    @State private var selectedAttachment: ReportIssueAttachment?

    @State private var showFileImporter = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("Station concernée") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(station.displayName)
                            .font(.headline)

                        if !station.subtitle.isEmpty {
                            Text(station.subtitle)
                                .foregroundStyle(.secondary)
                        }

                        Text("ID station : \(station.id)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Type de problème") {
                    Picker("Problème", selection: $selectedIssueType) {
                        ForEach(StationIssueType.allCases) { issue in
                            Text(issue.title).tag(issue)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Description") {
                    if selectedIssueType == .other {
                        Text("Décris le problème")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $message)
                            .frame(minHeight: 140)
                    } else {
                        Text("Tu peux ajouter un détail si besoin.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $message)
                            .frame(minHeight: 120)
                    }
                }

                Section("Pièce jointe") {
                    if let fileName = selectedFileName {
                        HStack {
                            Image(systemName: "paperclip")
                            Text(fileName)
                                .lineLimit(1)

                            Spacer()

                            Button("Retirer", role: .destructive) {
                                selectedFileName = nil
                                selectedAttachment = nil
                                selectedPhotoItem = nil
                            }
                        }
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Choisir une image", systemImage: "photo")
                    }

                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Choisir un fichier", systemImage: "doc")
                    }
                }

                Section {
                    Button {
                        Task {
                            await sendIssue()
                        }
                    } label: {
                        HStack {
                            Spacer()

                            if isSending {
                                ProgressView()
                            } else {
                                Text("Envoyer")
                                    .bold()
                            }

                            Spacer()
                        }
                    }
                    .disabled(isSending || !canSend)
                }
            }
            .navigationTitle("Signaler un problème")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [
                    .pdf,
                    .jpeg,
                    .png,
                    .plainText,
                    .text,
                    .data
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }

                Task {
                    await loadPhoto(from: newItem)
                }
            }
            .alert(item: $alertMessage) { item in
                Alert(
                    title: Text(item.title),
                    message: Text(item.message),
                    dismissButton: .default(Text("OK")) {
                        if item.shouldDismiss {
                            dismiss()
                        }
                    }
                )
            }
        }
    }

    private var canSend: Bool {
        if selectedIssueType == .other {
            return !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func sendIssue() async {
        guard !isSending else { return }

        isSending = true
        defer { isSending = false }

        do {
            try await ReportIssueAPI.shared.sendIssue(
                station: station,
                issueType: selectedIssueType,
                message: message,
                attachment: selectedAttachment
            )

            alertMessage = IssueAlertMessage(
                title: "Signalement envoyé",
                message: "Merci. Le signalement a bien été envoyé.",
                shouldDismiss: true
            )
        } catch {
            alertMessage = IssueAlertMessage(
                title: "Envoi impossible",
                message: error.localizedDescription,
                shouldDismiss: false
            )
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }

            let access = url.startAccessingSecurityScopedResource()
            defer {
                if access {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let fileName = url.lastPathComponent
            let mimeType = mimeTypeForFileExtension(url.pathExtension)

            selectedAttachment = ReportIssueAttachment(
                fileName: fileName,
                mimeType: mimeType,
                data: data
            )
            selectedFileName = fileName
        } catch {
            alertMessage = IssueAlertMessage(
                title: "Fichier impossible à lire",
                message: error.localizedDescription,
                shouldDismiss: false
            )
        }
    }

    private func loadPhoto(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw NSError(
                    domain: "ReportIssueView",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Image introuvable."]
                )
            }

            let fileName = "photo-\(UUID().uuidString).jpg"
            selectedAttachment = ReportIssueAttachment(
                fileName: fileName,
                mimeType: "image/jpeg",
                data: data
            )
            selectedFileName = fileName
        } catch {
            alertMessage = IssueAlertMessage(
                title: "Image impossible à charger",
                message: error.localizedDescription,
                shouldDismiss: false
            )
        }
    }

    private func mimeTypeForFileExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "pdf":
            return "application/pdf"
        case "txt":
            return "text/plain"
        default:
            return "application/octet-stream"
        }
    }
}

private struct IssueAlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let shouldDismiss: Bool
}
