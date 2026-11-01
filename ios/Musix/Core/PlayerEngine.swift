import Foundation
import AVFoundation
import MediaPlayer
import Combine

/// Audio playback, lock-screen controls and listening telemetry.
final class PlayerEngine: ObservableObject {

    static let shared = PlayerEngine()

    @Published private(set) var current: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var queue: [Track] = []
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var duration: Double = 0

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var lastTick = Date()
    private var artworkCache: [Int: MPMediaItemArtwork] = [:]

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, elapsed / duration))
    }

    var upNext: [Track] {
        guard let current else { return [] }
        guard let index = queue.firstIndex(where: { $0.id == current.id }) else { return [] }
        let start = queue.index(after: index)
        guard start < queue.count else { return [] }
        return Array(queue[start...])
    }

    private init() {
        configureAudioSession()
        configureRemoteCommands()
        observeInterruptions()
    }

    deinit {
        removeObservers()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Transport

    func play(_ track: Track, queue newQueue: [Track]? = nil) {
        if current?.id == track.id {
            if !isPlaying { resume() }
            return
        }

        if let newQueue, !newQueue.isEmpty {
            queue = newQueue
        } else if !queue.contains(where: { $0.id == track.id }) {
            queue = [track]
        }

        guard let url = track.url else { return }

        current = track
        elapsed = 0
        duration = Double(track.duration)

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 5

        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true

        player?.pause()
        removeObservers()
        player = newPlayer
        attachObservers(to: newPlayer)

        configureAudioSession()
        newPlayer.play()

        isPlaying = true
        isBuffering = true
        lastTick = Date()

        MusicStore.shared.markPlayed(track)
        ListeningStore.shared.begin(track)
        updateNowPlaying()
        WidgetBridge.publish(force: true)
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func resume() {
        guard let player else { return }
        configureAudioSession()
        player.play()
        isPlaying = true
        updateNowPlaying()
        WidgetBridge.publish(force: true)
    }

    func pause() {
        player?.pause()
        isPlaying = false
        ListeningStore.shared.flush()
        updateNowPlaying()
        WidgetBridge.publish(force: true)
    }

    func stop() {
        player?.pause()
        removeObservers()
        player = nil
        current = nil
        isPlaying = false
        elapsed = 0
        duration = 0
        queue = []
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        WidgetBridge.publish(force: true)
    }

    func seek(to fraction: Double) {
        guard let player, duration > 0 else { return }
        let target = min(max(fraction, 0), 1) * duration
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600),
                    toleranceBefore: .zero,
                    toleranceAfter: .zero)
        elapsed = target
        updateNowPlaying()
    }

    func next() {
        guard let current,
              let index = queue.firstIndex(where: { $0.id == current.id }) else { return }
        let nextIndex = queue.index(after: index)
        guard nextIndex < queue.count else {
            pause()
            return
        }
        play(queue[nextIndex])
    }

    func previous() {
        if elapsed > 3 {
            seek(to: 0)
            return
        }
        guard let current,
              let index = queue.firstIndex(where: { $0.id == current.id }),
              index > 0 else {
            seek(to: 0)
            return
        }
        play(queue[queue.index(before: index)])
    }

    // MARK: - Observers

    private func attachObservers(to player: AVPlayer) {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.handleTick(time)
        }

        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                             object: player.currentItem,
                                                             queue: .main) { [weak self] _ in
            guard let self else { return }
            ListeningStore.shared.flush()
            self.next()
        }
    }

    private func removeObservers() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    private func handleTick(_ time: CMTime) {
        let seconds = time.seconds
        guard seconds.isFinite else { return }

        elapsed = max(0, seconds)

        if let itemDuration = player?.currentItem?.duration.seconds,
           itemDuration.isFinite, itemDuration > 0 {
            duration = itemDuration
        }

        let status = player?.timeControlStatus
        isPlaying = status == .playing
        isBuffering = status == .waitingToPlayAtSpecifiedRate

        if isPlaying {
            let now = Date()
            let delta = min(1.5, max(0, now.timeIntervalSince(lastTick)))
            lastTick = now
            ListeningStore.shared.accumulate(seconds: delta)
        } else {
            lastTick = Date()
        }

        updateNowPlaying()
    }

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

            switch type {
            case .began:
                self.player?.pause()
                self.isPlaying = false
            case .ended:
                if let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
                    if options.contains(.shouldResume) { self.resume() }
                }
            @unknown default:
                break
            }
        }
    }

    // MARK: - Audio session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            // Playback still attempts; the error is non-fatal for streaming.
        }
    }

    // MARK: - Lock screen

    private func updateNowPlaying() {
        guard let current else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: current.title,
            MPMediaItemPropertyArtist: current.artist,
            MPMediaItemPropertyAlbumTitle: current.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: false
        ]

        if let artwork = artwork(for: current.palette) {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Cached lock-screen artwork for each palette.
    private func artwork(for palette: Int) -> MPMediaItemArtwork? {
        if let cached = artworkCache[palette] { return cached }
        guard let image = CoverRenderer.image(palette: palette) else { return nil }
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        artworkCache[palette] = artwork
        return artwork
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let event = event as? MPChangePlaybackPositionCommandEvent,
                  self.duration > 0 else { return .commandFailed }
            self.seek(to: event.positionTime / self.duration)
            return .success
        }
    }
}
