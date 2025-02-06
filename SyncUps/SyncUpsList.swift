import Dependencies
import IdentifiedCollections
import IssueReporting
import Sharing
import SwiftUI
import SwiftUINavigation

@MainActor
@Observable
final class SyncUpsListModel {
  var addSyncUp: SyncUpFormModel?
  @ObservationIgnored @Shared(.syncUps) var syncUps

  @ObservationIgnored @Dependency(\.uuid) var uuid

  init(
    addSyncUp: SyncUpFormModel? = nil
  ) {
    self.addSyncUp = addSyncUp
  }

  func addSyncUpButtonTapped() {
    addSyncUp = withDependencies(from: self) {
      SyncUpFormModel(syncUp: SyncUp(id: SyncUp.ID(uuid())))
    }
  }

  func dismissAddSyncUpButtonTapped() {
    addSyncUp = nil
  }

  func confirmAddSyncUpButtonTapped() {
    defer { addSyncUp = nil }

    guard let syncUpFormModel = addSyncUp
    else { return }
    var syncUp = syncUpFormModel.syncUp

    syncUp.attendees.removeAll { attendee in
      attendee.name.allSatisfy(\.isWhitespace)
    }
    if syncUp.attendees.isEmpty {
      syncUp.attendees.append(Attendee(id: Attendee.ID(uuid())))
    }
    _ = $syncUps.withLock { $0.append(syncUp) }
  }

  func loadSampleDataButtonTapped() {
    withAnimation {
      $syncUps.withLock {
        $0 = [
          .mock,
          .engineeringMock,
          .designMock,
        ]
      }
    }
  }
}

struct SyncUpsList: View {
  @Bindable var model: SyncUpsListModel

  var body: some View {
    List {
      if let loadError = model.$syncUps.loadError {
        ContentUnavailableView {
          Label("An error occurred", systemImage: "exclamationmark.octagon")
        } description: {
          Text(loadError.localizedDescription)
        } actions: {
          Button("Load sample data") {
            model.loadSampleDataButtonTapped()
          }
        }
      } else {
        ForEach(Array(model.$syncUps)) { $syncUp in
          NavigationLink(
            value: AppModel.Path.detail(SyncUpDetailModel(syncUp: $syncUp))
          ) {
            CardView(syncUp: syncUp)
          }
          .listRowBackground(syncUp.theme.mainColor)
        }
      }
    }
    .toolbar {
      Button {
        model.addSyncUpButtonTapped()
      } label: {
        Image(systemName: "plus")
      }
    }
    .navigationTitle("Daily Sync-ups")
    .sheet(item: $model.addSyncUp) { syncUpFormModel in
      NavigationStack {
        SyncUpFormView(model: syncUpFormModel)
          .navigationTitle("New sync-up")
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Dismiss") {
                model.dismissAddSyncUpButtonTapped()
              }
            }
            ToolbarItem(placement: .confirmationAction) {
              Button("Add") {
                model.confirmAddSyncUpButtonTapped()
              }
            }
          }
      }
    }
  }
}

struct CardView: View {
  let syncUp: SyncUp

  var body: some View {
    VStack(alignment: .leading) {
      Text(syncUp.title)
        .font(.headline)
      Spacer()
      HStack {
        Label("\(syncUp.attendees.count)", systemImage: "person.3")
        Spacer()
        Label(syncUp.duration.formatted(.units()), systemImage: "clock")
          .labelStyle(.trailingIcon)
      }
      .font(.caption)
    }
    .padding()
    .foregroundColor(syncUp.theme.accentColor)
  }
}

struct TrailingIconLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack {
      configuration.title
      configuration.icon
    }
  }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
  static var trailingIcon: Self { Self() }
}

extension SharedReaderKey where Self == FileStorageKey<IdentifiedArrayOf<SyncUp>>.Default {
  static var syncUps: Self {
    Self[
      .fileStorage(dump(URL.documentsDirectory.appending(component: "sync-ups.json"))),
      default: isTesting || ProcessInfo.processInfo.environment["UI_TEST_NAME"] != nil ? [] : [
        .mock,
        .engineeringMock,
        .designMock,
      ]
    ]
  }
}

#Preview("Mocking initial sync-ups") {
  Preview(
    message: """
      This preview demonstrates how to start the app in a state with a few sync-ups \
      pre-populated. Since the initial sync-ups are loaded from disk we cannot simply pass some \
      data to the SyncUpsList model. But, we can override the DataManager dependency so that \
      when its load endpoint is called it will load whatever data we want.
      """
  ) {
    @Shared(.syncUps) var syncUps: IdentifiedArray = [
      .mock,
      .engineeringMock,
      .designMock,
    ]
    NavigationStack {
      SyncUpsList(model: SyncUpsListModel())
    }
  }
}

#Preview("Deep link add flow") {
  Preview(
    message: """
      The preview demonstrates how you can start the application navigated to a very specific \
      screen just by constructing a piece of state. In particular we will start the app with the \
      "Add sync-up" screen opened and with the last attendee text field focused.
      """
  ) {
    var syncUp = SyncUp.mock
    let lastAttendee = Attendee(id: Attendee.ID())
    let _ = syncUp.attendees.append(lastAttendee)
    NavigationStack {
      SyncUpsList(
        model: SyncUpsListModel(
          addSyncUp: SyncUpFormModel(
            focus: .attendee(lastAttendee.id),
            syncUp: syncUp
          )
        )
      )
    }
  }
}
