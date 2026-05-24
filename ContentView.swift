//
//  ContentView.swift
//  OscarGo
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var recorder = Recorder()

    var body: some View {
        VStack(spacing: 28) {
            Text("OscarGo")
                .font(.largeTitle).bold()

            Text(recorder.isRecording ? "● Recording…" : "Ready")
                .font(.title3)
                .foregroundColor(recorder.isRecording ? .red : .secondary)

            Button {
                recorder.toggle()
            } label: {
                Circle()
                    .fill(recorder.isRecording ? Color.red : Color.blue)
                    .frame(width: 220, height: 220)
                    .overlay(
                        Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 90))
                    )
                    .shadow(radius: 8)
            }
            .buttonStyle(.plain)

            Text("\(recorder.clipCount) clip(s) saved on phone")
                .foregroundColor(.secondary)

            if let err = recorder.errorMsg {
                Text(err).foregroundColor(.red).font(.caption)
            }
        }
        .padding()
        .onAppear { recorder.requestPermission() }
    }
}

final class Recorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var clipCount = 0
    @Published var errorMsg: String?

    private var audioRecorder: AVAudioRecorder?

    func requestPermission() {
        AVAudioApplication.requestRecordPermission { _ in }
        refreshCount()
    }

    func toggle() {
        isRecording ? stop() : start()
    }

    private func start() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let stamp = Int(Date().timeIntervalSince1970)
            let url = documentsURL().appendingPathComponent("clip_\(stamp).m4a")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.record()
            audioRecorder = rec
            isRecording = true
            errorMsg = nil
        } catch {
            errorMsg = "Record failed: \(error.localizedDescription)"
        }
    }

    private func stop() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        refreshCount()
    }

    private func refreshCount() {
        let files = (try? FileManager.default.contentsOfDirectory(at: documentsURL(), includingPropertiesForKeys: nil)) ?? []
        clipCount = files.filter { $0.pathExtension == "m4a" }.count
    }

    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

#Preview {
    ContentView()
}
