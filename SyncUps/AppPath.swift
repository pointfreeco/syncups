import Foundation
import Sharing

enum AppPath: Codable, Hashable {
  case detail(id: SyncUp.ID)
  case meeting(id: Meeting.ID, syncUpID: SyncUp.ID)
  case record(id: SyncUp.ID)

  // NB: Encode only certain paths for state restoration.
  var isRestorable: Bool {
    switch self {
    case .detail, .meeting: true
    case .record: false
    }
  }
}

extension SharedReaderKey where Self == FileStorageKey<[AppPath]>.Default {
  static var path: Self {
    Self[
      .fileStorage(
        .documentsDirectory.appending(path: "path.json"),
        decode: { data in
          try JSONDecoder().decode([AppPath].self, from: data)
        },
        encode: { path in
          try JSONEncoder().encode(path.filter(\.isRestorable))
        }
      ),
      default: []
    ]
  }
}
