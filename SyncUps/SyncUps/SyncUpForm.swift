import Dependencies
import SwiftUI
import SwiftUINavigation

@Observable
final class SyncUpFormModel: Identifiable {
  var focus: Field?
  var syncUp: SyncUp

  @ObservationIgnored @Dependency(\.uuid) var uuid

  enum Field: Hashable {
    case attendee(Attendee.ID)
    case title
  }

  init(
    focus: Field? = .title,
    syncUp: SyncUp
  ) {
    self.focus = focus
    self.syncUp = syncUp
    if syncUp.attendees.isEmpty {
      self.syncUp.attendees.append(Attendee(id: Attendee.ID(uuid())))
    }
  }

  func deleteAttendees(atOffsets indices: IndexSet) {
    syncUp.attendees.remove(atOffsets: indices)
    if syncUp.attendees.isEmpty {
      syncUp.attendees.append(Attendee(id: Attendee.ID(uuid())))
    }
    guard let firstIndex = indices.first
    else { return }
    let index = min(firstIndex, syncUp.attendees.count - 1)
    focus = .attendee(syncUp.attendees[index].id)
  }

  func addAttendeeButtonTapped() {
    let attendee = Attendee(id: Attendee.ID(uuid()))
    syncUp.attendees.append(attendee)
    focus = .attendee(attendee.id)
  }
}

struct SyncUpFormView: View {
  @FocusState var focus: SyncUpFormModel.Field?
  @Bindable var model: SyncUpFormModel

  var body: some View {
    Form {
      Section {
        TextField("Title", text: $model.syncUp.title)
          .focused($focus, equals: .title)
        HStack {
          Slider(value: $model.syncUp.duration.seconds, in: 5...30, step: 1) {
            Text("Length")
          }
          Spacer()
          Text(model.syncUp.duration.formatted(.units()))
        }
        ThemePicker(selection: $model.syncUp.theme)
      } header: {
        Text("Sync-up Info")
      }
      Section {
        ForEach($model.syncUp.attendees) { $attendee in
          TextField("Name", text: $attendee.name)
            .focused($focus, equals: .attendee(attendee.id))
        }
        .onDelete { indices in
          model.deleteAttendees(atOffsets: indices)
        }

        Button("New attendee") {
          model.addAttendeeButtonTapped()
        }
      } header: {
        Text("Attendees")
      }
    }
    .bind($model.focus, to: $focus)
  }
}

struct ThemePicker: View {
  @Binding var selection: Theme

  var body: some View {
    Picker("Theme", selection: $selection) {
      ForEach(Theme.allCases) { theme in
        ZStack {
          RoundedRectangle(cornerRadius: 4)
            .fill(theme.mainColor)
          Label(theme.name, systemImage: "paintpalette")
            .padding(4)
        }
        .foregroundColor(theme.accentColor)
        .fixedSize(horizontal: false, vertical: true)
        .tag(theme)
      }
    }
  }
}

extension Duration {
  fileprivate var seconds: Double {
    get { Double(components.seconds / 60) }
    set { self = .seconds(newValue * 60) }
  }
}

struct SyncUpForm_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      SyncUpFormView(model: SyncUpFormModel(syncUp: .mock))
    }
    .previewDisplayName("Edit")

    Preview(
      message: """
        This preview shows how we can start the screen if a very specific state, where the 4th \
        attendee is already focused.
        """
    ) {
      NavigationStack {
        SyncUpFormView(
          model: SyncUpFormModel(
            focus: .attendee(SyncUp.mock.attendees[3].id),
            syncUp: .mock
          )
        )
      }
    }
    .previewDisplayName("4th attendee focused")
  }
}
