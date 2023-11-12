import Dependencies
import IdentifiedCollections
import SwiftUI
import SwiftUINavigation

@MainActor
@Observable
final class SyncUpsListModel {
  var destination: Destination? {
    didSet { self.bind() }
  }
  var syncUps: IdentifiedArrayOf<SyncUp> {
    didSet {
      self.saveDebouncedTask?.cancel()
      self.saveDebouncedTask = Task {
        try await self.clock.sleep(for: .seconds(1))
        try self.dataManager.save(JSONEncoder().encode(self.syncUps), to: .syncUps)
      }
    }
  }
  private var saveDebouncedTask: Task<Void, Error>?

  @ObservationIgnored
  @Dependency(\.continuousClock) var clock
  @ObservationIgnored
  @Dependency(\.dataManager) var dataManager
  @ObservationIgnored
  @Dependency(\.uuid) var uuid

  @CasePathable
  @dynamicMemberLookup
  enum Destination {
    case add(SyncUpFormModel)
    case alert(AlertState<AlertAction>)
    case detail(SyncUpDetailModel)
  }
  enum AlertAction {
    case confirmLoadMockData
  }

  init(
    destination: Destination? = nil
  ) {
    defer { self.bind() }
    self.destination = destination
    self.syncUps = []

    do {
      self.syncUps = try JSONDecoder().decode(
        IdentifiedArray.self,
        from: self.dataManager.load(from: .syncUps)
      )
    } catch is DecodingError {
      self.destination = .alert(.dataFailedToLoad)
    } catch {
    }
  }

  func addSyncUpButtonTapped() {
    self.destination = .add(
      withDependencies(from: self) {
        SyncUpFormModel(syncUp: SyncUp(id: SyncUp.ID(self.uuid())))
      }
    )
  }

  func dismissAddSyncUpButtonTapped() {
    self.destination = nil
  }

  func confirmAddSyncUpButtonTapped() {
    defer { self.destination = nil }

    guard case let .add(syncUpFormModel) = self.destination
    else { return }
    var syncUp = syncUpFormModel.syncUp

    syncUp.attendees.removeAll { attendee in
      attendee.name.allSatisfy(\.isWhitespace)
    }
    if syncUp.attendees.isEmpty {
      syncUp.attendees.append(Attendee(id: Attendee.ID(self.uuid())))
    }
    self.syncUps.append(syncUp)
  }

  func syncUpTapped(syncUp: SyncUp) {
    self.destination = .detail(
      withDependencies(from: self) {
        SyncUpDetailModel(syncUp: syncUp)
      }
    )
  }

  private func bind() {
    switch self.destination {
    case let .detail(syncUpDetailModel):
      syncUpDetailModel.onConfirmDeletion = { [weak self, id = syncUpDetailModel.syncUp.id] in
        withAnimation {
          self?.syncUps.remove(id: id)
          self?.destination = nil
        }
      }

      syncUpDetailModel.onSyncUpUpdated = { [weak self] syncUp in
        self?.syncUps[id: syncUp.id] = syncUp
      }

    case .add, .alert, .none:
      break
    }
  }

  func alertButtonTapped(_ action: AlertAction?) {
    switch action {
    case .confirmLoadMockData?:
      withAnimation {
        self.syncUps = [
          .mock,
          .designMock,
          .engineeringMock,
        ]
      }
    case nil:
      break
    }
  }
}

extension AlertState where Action == SyncUpsListModel.AlertAction {
  static let dataFailedToLoad = Self {
    TextState("Data failed to load")
  } actions: {
    ButtonState(action: .confirmLoadMockData) {
      TextState("Yes")
    }
    ButtonState(role: .cancel) {
      TextState("No")
    }
  } message: {
    TextState(
      """
      Unfortunately your past data failed to load. Would you like to load some mock data to play \
      around with?
      """)
  }
}

struct SyncUpsList: View {
  @State var model: SyncUpsListModel

  var body: some View {
    NavigationStack {
      List {
        ForEach(self.model.syncUps) { syncUp in
          Button {
            self.model.syncUpTapped(syncUp: syncUp)
          } label: {
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
      .navigationDestination(item: self.$model.destination.detail) { detailModel in
        SyncUpDetailView(model: detailModel)
      }
      .alert(self.$model.destination.alert) {
        self.model.alertButtonTapped($0)
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

extension URL {
  fileprivate static let syncUps = Self.documentsDirectory.appending(component: "sync-ups.json")
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
      SyncUpsList(
        model: withDependencies {
          $0.dataManager = .mock(
            initialData: try! JSONEncoder().encode([
              SyncUp.mock,
              .engineeringMock,
              .designMock,
            ])
          )
        } operation: {
          SyncUpsListModel()
        }
      )
    }
    .previewDisplayName("Mocking initial sync-ups")

    Preview(
      message: """
        This preview demonstrates how to test the flow of loading bad data from disk, in which \
        case an alert should be shown. This can be done by overridding the DataManager dependency \
        so that its initial data does not properly decode into a collection of sync-ups.
        """
    ) {
      SyncUpsList(
        model: withDependencies {
          $0.dataManager = .mock(
            initialData: Data("!@#$% bad data ^&*()".utf8)
          )
        } operation: {
          SyncUpsListModel()
        }
      )
    }
    .previewDisplayName("Load data failure")

    Preview(
      message: """
        The preview demonstrates how you can start the application navigated to a very specific \
        screen just by constructing a piece of state. In particular we will start the app drilled \
        down to the detail screen of a sync-up, and then further drilled down to the record screen \
        for a new meeting.
        """
    ) {
      SyncUpsList(
        model: withDependencies {
          $0.dataManager = .mock(
            initialData: try! JSONEncoder().encode([
              SyncUp.mock,
              .engineeringMock,
              .designMock,
            ])
          )
        } operation: {
          SyncUpsListModel(
            destination: .detail(
              SyncUpDetailModel(
                destination: .record(
                  RecordMeetingModel(syncUp: .mock)
                ),
                syncUp: .mock
              )
            )
          )
        }
      )
    }
    .previewDisplayName("Deep link record flow")

    Preview(
      message: """
        The preview demonstrates how you can start the application navigated to a very specific \
        screen just by constructing a piece of state. In particular we will start the app with the \
        "Add sync-up" screen opened and with the last attendee text field focused.
        """
    ) {
      SyncUpsList(
        model: withDependencies {
          $0.dataManager = .mock()
        } operation: {
          var syncUp = SyncUp.mock
          let lastAttendee = Attendee(id: Attendee.ID())
          let _ = syncUp.attendees.append(lastAttendee)
          return SyncUpsListModel(
            destination: .add(
              SyncUpFormModel(
                focus: .attendee(lastAttendee.id),
                syncUp: syncUp
              )
            )
          )
        }
      )
    }
    .previewDisplayName("Deep link add flow")
  }
}
