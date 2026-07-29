import SwiftUI

struct SetupView: View {
  @Bindable var model: SetupModel

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      header
      status
      setup
      controlCentreInstructions
      actions
    }
    .frame(width: 480)
    .padding(28)
    .task {
      model.refresh()
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Clamshell")
        .font(.largeTitle.bold())
      Text("Control battery clamshell mode from Control Centre or Terminal.")
        .foregroundStyle(.secondary)
    }
  }

  private var status: some View {
    HStack(spacing: 14) {
      Image(systemName: model.state.symbolName)
        .font(.title2)
        .foregroundStyle(model.state.tint)
        .frame(width: 28)

      VStack(alignment: .leading, spacing: 3) {
        Text(model.state.title)
          .font(.headline)
        Text(model.state.detail)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(16)
    .background(.quaternary, in: .rect(cornerRadius: 12))
  }

  @ViewBuilder
  private var setup: some View {
    if model.state != .ready {
      VStack(alignment: .leading, spacing: 12) {
        Toggle("Install the Terminal command", isOn: $model.exposeCommand)
          .disabled(model.state == .missingBundlePayload || model.isWorking)
        Text("This optional setting adds clamshellctl to /usr/local/bin.")
          .font(.caption)
          .foregroundStyle(.secondary)

        Button("Set Up") {
          Task { await model.setUp() }
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.state == .missingBundlePayload || model.isWorking)
      }
    }
  }

  private var controlCentreInstructions: some View {
    GroupBox("Add the control") {
      Text("Open Control Centre and select Edit Controls. Add Battery Clamshell Mode.")
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
  }

  private var actions: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let errorMessage = model.errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.red)
      }

      HStack {
        Button("Refresh") {
          model.refresh()
        }
        .disabled(model.isWorking)

        if model.state == .ready {
          Button("Install Terminal Command") {
            Task { await model.installTerminalCommand() }
          }
          .disabled(model.isWorking)
        }

        Spacer()

        if model.state == .ready || model.state == .invalidHelper {
          Button("Remove Privileged Setup", role: .destructive) {
            Task { await model.removePrivilegedSetup() }
          }
          .disabled(model.isWorking)
        }
      }
    }
  }
}

private extension SetupState {
  var title: String {
    switch self {
    case .needsSetup:
      "Setup required"
    case .ready:
      "Ready"
    case .invalidHelper:
      "Setup needs repair"
    case .missingBundlePayload:
      "App files are incomplete"
    }
  }

  var detail: String {
    switch self {
    case .needsSetup:
      "Install the restricted helper to enable the control."
    case .ready:
      "The Control Centre control is ready."
    case .invalidHelper:
      "Run setup again to replace the invalid helper files."
    case .missingBundlePayload:
      "Install a complete Clamshell app and try again."
    }
  }

  var symbolName: String {
    switch self {
    case .needsSetup:
      "lock.shield"
    case .ready:
      "checkmark.circle.fill"
    case .invalidHelper, .missingBundlePayload:
      "exclamationmark.triangle.fill"
    }
  }

  var tint: Color {
    switch self {
    case .needsSetup:
      .accentColor
    case .ready:
      .green
    case .invalidHelper, .missingBundlePayload:
      .orange
    }
  }
}
