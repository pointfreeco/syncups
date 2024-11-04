import Dependencies
import IdentifiedCollections
import IssueReporting
import Sharing
import SwiftUI
import SwiftUINavigation

@MainActor
@Observable
final class SyncUpsListModel {
  var destination: Destination?
  @ObservationIgnored
  @Shared(.syncUps) var syncUps

  @ObservationIgnored
  @Dependency(\.continuousClock) var clock
  @ObservationIgnored
  @Dependency(\.uuid) var uuid

  @CasePathable
  @dynamicMemberLookup
  enum Destination {
    case add(SyncUpFormModel)
  }

  init(
    destination: Destination? = nil
  ) {
    self.destination = destination
  }

  func addSyncUpButtonTapped() {
    destination = .add(
      withDependencies(from: self) {
        SyncUpFormModel(syncUp: SyncUp(id: SyncUp.ID(self.uuid())))
      }
    )
  }

  func dismissAddSyncUpButtonTapped() {
    destination = nil
  }

  func confirmAddSyncUpButtonTapped() {
    defer { destination = nil }

    guard case let .add(syncUpFormModel) = destination
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
}

struct SyncUpsList: View {
  @State var model = SyncUpsListModel()

  var body: some View {
    List {
      ForEach(self.model.syncUps) { syncUp in
        NavigationLink(value: AppPath.detail(id: syncUp.id)) {
          CardView(syncUp: syncUp)
        }
        .listRowBackground(syncUp.theme.mainColor)
      }
    }
    .toolbar {
      Button {
        self.model.addSyncUpButtonTapped()
      } label: {
        Image(systemName: "plus")
      }
    }
    .navigationTitle("Daily Sync-ups")
    .sheet(item: self.$model.destination.add) { model in
      NavigationStack {
        SyncUpFormView(model: model)
          .navigationTitle("New sync-up")
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Dismiss") {
                self.model.dismissAddSyncUpButtonTapped()
              }
            }
            ToolbarItem(placement: .confirmationAction) {
              Button("Add") {
                self.model.confirmAddSyncUpButtonTapped()
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
      Text(self.syncUp.title)
        .font(.headline)
      Spacer()
      HStack {
        Label("\(self.syncUp.attendees.count)", systemImage: "person.3")
        Spacer()
        Label(self.syncUp.duration.formatted(.units()), systemImage: "clock")
          .labelStyle(.trailingIcon)
      }
      .font(.caption)
    }
    .padding()
    .foregroundColor(self.syncUp.theme.accentColor)
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

extension PersistenceReaderKey where Self == FileStorageKey<IdentifiedArrayOf<SyncUp>>.Default {
  static var syncUps: Self {
    Self[.fileStorage(URL.documentsDirectory.appending(component: "sync-ups.json")), default: []]
  }
}

struct SyncUpsList_Previews: PreviewProvider {
  static var previews: some View {
    Preview(
      message: """
        This preview demonstrates how to start the app in a state with a few sync-ups \
        pre-populated. Since the initial sync-ups are loaded from disk we cannot simply pass some \
        data to the SyncUpsList model. But, we can override the DataManager dependency so that \
        when its load endpoint is called it will load whatever data we want.
        """
    ) {
      @Shared(.syncUps) var syncUps: IdentifiedArray = [
        SyncUp.mock,
        .engineeringMock,
        .designMock,
      ]
      SyncUpsList(model: SyncUpsListModel())
    }
    .previewDisplayName("Mocking initial sync-ups")

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
      SyncUpsList(
        model: SyncUpsListModel(
          destination: .add(
            SyncUpFormModel(
              focus: .attendee(lastAttendee.id),
              syncUp: syncUp
            )
          )
        )
      )
    }
    .previewDisplayName("Deep link add flow")
  }
}
