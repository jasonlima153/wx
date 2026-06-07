import Foundation
import AVFoundation
import Combine

final class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    private var recorder: AVAudioRecorder?

    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("record.m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        recorder = try? AVAudioRecorder(url: url, settings: settings)
        recorder?.delegate = self
        recorder?.record()
        isRecording = true
    }

    func stop() {
        recorder?.stop()
        isRecording = false
    }

    var recordedFileURL: URL? {
        recorder?.url
    }
}
