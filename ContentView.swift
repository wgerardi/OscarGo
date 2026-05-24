//
//  ContentView.swift
//  OscarGo — Win2000 OSCAR Capture look
//

import SwiftUI
import AVFoundation
import Combine

// ===== Win2000 OSCAR palette =====
private let face     = Color(red: 0.83, green: 0.82, blue: 0.78)   // #d4d0c8 button-face
private let work     = Color.white                                  // sunken white work area
private let ink      = Color(red: 0.10, green: 0.10, blue: 0.10)
private let dim      = Color(red: 0.35, green: 0.35, blue: 0.35)
private let titleA   = Color(red: 0.23, green: 0.43, blue: 0.65)   // #3a6ea5
private let titleB   = Color(red: 0.12, green: 0.23, blue: 0.34)   // #1f3a57
private let recOff   = Color(red: 0.80, green: 0.27, blue: 0.27)   // #cc4444
private let recOn    = Color(red: 0.24, green: 0.54, blue: 0.29)   // #3c8a4a
private let cancelOff = Color(red: 0.78, green: 0.77, blue: 0.74) // #c8c4bc
private let accent   = Color(red: 0.40, green: 0.60, blue: 0.80)
private let accDeep  = Color(red: 0.23, green: 0.43, blue: 0.65)

// ===== Faux Win2000 bevel (raised) =====
struct BevelRaised: View {
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle().fill(Color.white).frame(height: 2)
                Spacer()
                Rectangle().fill(Color.black.opacity(0.45)).frame(height: 2)
            }
            HStack(spacing: 0) {
                Rectangle().fill(Color.white).frame(width: 2)
                Spacer()
                Rectangle().fill(Color.black.opacity(0.45)).frame(width: 2)
            }
        }
        .allowsHitTesting(false)
    }
}

// ===== Main view =====
struct ContentView: View {
    @StateObject private var recorder = Recorder()
    @State private var pulseOn = false

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("🎙️  OSCAR Capture")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                LinearGradient(colors: [titleA, titleB],
                               startPoint: .leading, endPoint: .trailing)
            )

            // ---- Window: the two big buttons ----
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    bigButton(
                        color: recorder.isRecording ? recOn : recOff,
                        icon: "mic.fill",
                        label: recorder.isRecording ? "STOP & SEND" : "RECORD",
                        opacity: recorder.isRecording && pulseOn ? 0.65 : 1.0
                    ) { recorder.toggle() }

                    bigButton(
                        color: cancelOff,
                        icon: "trash",
                        label: "CANCEL",
                        opacity: recorder.isRecording ? 1.0 : 0.55
                    ) { recorder.cancel() }
                    .disabled(!recorder.isRecording)
                }
            }
            .padding(10)
            .background(face)
            .overlay(BevelRaised())
            .padding(10)

            // ---- Status line ----
            Text(statusLine)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(statusColor)
                .frame(minHeight: 18)
                .padding(.bottom, 8)

            // ---- Clip count panel ----
            VStack(alignment: .leading, spacing: 4) {
                Text("CLIPS ON PHONE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(dim)
                Text("\(recorder.clipCount)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(ink)
                Text(recorder.clipCount == 0 ? "Nothing yet — hit RECORD" : "Will sync when home (later build)")
                    .font(.system(size: 11))
                    .foregroundColor(dim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(face)
            .overlay(BevelRaised())
            .padding(.horizontal, 10)

            Spacer()

            // ---- Footer ----
            Text("OscarGo · early build")
                .font(.system(size: 10))
                .foregroundColor(dim)
                .padding(.bottom, 12)
        }
        .background(face.ignoresSafeArea())
        .onAppear {
            recorder.requestPermission()
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulseOn = true
            }
        }
    }

    private var statusLine: String {
        if let err = recorder.errorMsg { return "✗ \(err)" }
        if recorder.isRecording { return "● RECORDING…" }
        if recorder.justSaved { return "✓ Saved on phone" }
        if recorder.justCancelled { return "✕ Clip scrapped" }
        return " "
    }
    private var statusColor: Color {
        if recorder.errorMsg != nil { return .red }
        if recorder.isRecording { return recOn }
        if recorder.justSaved { return accDeep }
        if recorder.justCancelled { return dim }
        return dim
    }

    // Big square button with bevel
    @ViewBuilder
    private func bigButton(color: Color, icon: String, label: String,
                           opacity: Double, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                Text(label)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .background(color)
            .overlay(BevelRaised())
            .opacity(opacity)
        }
        .buttonStyle(.plain)
    }
}

// ===== Recorder =====
final class Recorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var clipCount = 0
    @Published var errorMsg: String?
    @Published var justSaved = false
    @Published var justCancelled = false

    private var audioRecorder: AVAudioRecorder?
    private var didCancel = false

    func requestPermission() {
        AVAudioApplication.requestRecordPermission { _ in }
        refreshCount()
    }

    func toggle() {
        isRecording ? stop() : start()
    }

    func cancel() {
        guard isRecording else { return }
        didCancel = true
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        justCancelled = true
        justSaved = false
        // delete the just-recorded file if any
        if let last = newestClipURL() {
            try? FileManager.default.removeItem(at: last)
        }
        refreshCount()
        flashClear()
    }

    private func start() {
        errorMsg = nil
        justSaved = false
        justCancelled = false
        didCancel = false
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
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func stop() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        if !didCancel {
            justSaved = true
            justCancelled = false
        }
        refreshCount()
        flashClear()
    }

    private func flashClear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.justSaved = false
            self?.justCancelled = false
        }
    }

    private func refreshCount() {
        let files = (try? FileManager.default.contentsOfDirectory(at: documentsURL(), includingPropertiesForKeys: nil)) ?? []
        clipCount = files.filter { $0.pathExtension == "m4a" }.count
    }

    private func newestClipURL() -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(at: documentsURL(), includingPropertiesForKeys: [.creationDateKey])) ?? []
        return files
            .filter { $0.pathExtension == "m4a" }
            .sorted { (a, b) -> Bool in
                let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return da > db
            }
            .first
    }

    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

#Preview {
    ContentView()
}
