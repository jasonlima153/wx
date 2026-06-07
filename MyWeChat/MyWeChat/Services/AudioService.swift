import Foundation
import AVFoundation

// MARK: - 语音播放和录音服务
class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()

    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingDuration: Double = 0

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var currentPlayingMessageID: String?

    private override init() {
        super.init()
    }

    // MARK: - 录音

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)

            let url = getRecordingURL()
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordingDuration = 0

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.recordingDuration += 0.1
            }

            print("🎙️ 开始录音")
        } catch {
            print("❌ 录音启动失败: \(error)")
        }
    }

    func stopRecording() -> Data? {
        audioRecorder?.stop()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil

        let url = getRecordingURL()
        let duration = audioRecorder?.currentTime ?? 0
        print("🎙️ 录音结束，时长: \(String(format: "%.1f", duration))秒")

        if let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }

    func cancelRecording() {
        audioRecorder?.stop()
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0

        // 删除录音文件
        try? FileManager.default.removeItem(at: getRecordingURL())
    }

    // MARK: - 播放

    func playVoice(url: URL, messageID: String) {
        stopPlaying()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            currentPlayingMessageID = messageID
            audioPlayer?.play()
            isPlaying = true
            print("🔊 播放语音")
        } catch {
            print("❌ 播放失败: \(error)")
        }
    }

    func playVoiceFromURLString(_ urlString: String, messageID: String) {
        // 先检查本地缓存
        let baseURL = WebSocketManager.shared.serverURL.replacingOccurrences(of: "/ws", with: "")
        let fullURLString = urlString.hasPrefix("http") ? urlString : "\(baseURL)\(urlString)"

        guard let url = URL(string: fullURLString) else { return }

        // 下载后播放
        URLSession.shared.downloadTask(with: url) { [weak self] localURL, _, error in
            guard let localURL = localURL else { return }
            // 移动到临时目录防止被删除
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".aac")
            try? FileManager.default.moveItem(at: localURL, to: tempFile)

            DispatchQueue.main.async {
                self?.playVoice(url: tempFile, messageID: messageID)
            }
        }.resume()
    }

    func stopPlaying() {
        audioPlayer?.stop()
        isPlaying = false
        currentPlayingMessageID = nil
    }

    // MARK: - 私有辅助

    private func getRecordingURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("voice_recording.aac")
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentPlayingMessageID = nil
        }
    }
}
