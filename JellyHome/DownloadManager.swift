import AVFoundation
import Combine
import SwiftUI

@MainActor
final class DownloadManager: ObservableObject {
    @Published var activeDownloads: [URL] = []

    func enqueueDownload(_ url: URL) {
        if !activeDownloads.contains(url) {
            activeDownloads.append(url)
        }
    }

    func removeDownload(_ url: URL) {
        activeDownloads.removeAll { $0 == url }
    }
}
