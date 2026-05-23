import SwiftUI
import AppKit

@MainActor
struct WindowHotkeySettingsView: View {
    @State private var recordingAction: WindowAction?
    @State private var eventMonitor: Any?
    @AppStorage("flick.windowHotkey.leftHalf") private var leftHalf: Int = 0
    @AppStorage("flick.windowHotkey.rightHalf") private var rightHalf: Int = 0
    @AppStorage("flick.windowHotkey.topHalf") private var topHalf: Int = 0
    @AppStorage("flick.windowHotkey.bottomHalf") private var bottomHalf: Int = 0
    @AppStorage("flick.windowHotkey.maximize") private var maximize: Int = 0
    @AppStorage("flick.windowHotkey.center") private var center: Int = 0
    @AppStorage("flick.windowHotkey.leftThird") private var leftThird: Int = 0
    @AppStorage("flick.windowHotkey.centerThird") private var centerThird: Int = 0
    @AppStorage("flick.windowHotkey.rightThird") private var rightThird: Int = 0

    var body: some View {
        Form {
            Section("Window Hotkeys") {
                ForEach(WindowAction.allCases) { action in
                    HStack {
                        Text(action.name)
                        Spacer()
                        let keyCode = storedKeyCode(for: action)
                        if keyCode == 0 {
                            Text("—").foregroundStyle(.secondary)
                        } else {
                            Text(hotkeyDescription(keyCode: keyCode, modifiers: 0))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .cornerRadius(4)
                                .fontDesign(.monospaced)
                                .font(.caption)
                        }
                        if recordingAction == action {
                            Text("Press key…")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            Button("Cancel") {
                                stopRecording()
                            }
                            .controlSize(.small)
                        } else {
                            Button("Assign") {
                                startRecording(for: action)
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onDisappear { stopRecording() }
    }

    private func storedKeyCode(for action: WindowAction) -> Int {
        switch action {
        case .leftHalf: leftHalf
        case .rightHalf: rightHalf
        case .topHalf: topHalf
        case .bottomHalf: bottomHalf
        case .maximize: maximize
        case .center: center
        case .leftThird: leftThird
        case .centerThird: centerThird
        case .rightThird: rightThird
        }
    }

    private func setKeyCode(_ keyCode: Int, for action: WindowAction) {
        switch action {
        case .leftHalf: leftHalf = keyCode
        case .rightHalf: rightHalf = keyCode
        case .topHalf: topHalf = keyCode
        case .bottomHalf: bottomHalf = keyCode
        case .maximize: maximize = keyCode
        case .center: center = keyCode
        case .leftThird: leftThird = keyCode
        case .centerThird: centerThird = keyCode
        case .rightThird: rightThird = keyCode
        }
    }

    private func startRecording(for action: WindowAction) {
        stopRecording()
        recordingAction = action
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.setKeyCode(Int(event.keyCode), for: action)
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        recordingAction = nil
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
