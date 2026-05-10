import AVKit
import Combine
import SwiftUI

@MainActor
final class PlayerCoordinator: ObservableObject {
    @Published var player = AVPlayer()

    func play(url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
}
