import CasePaths
import Foundation
import Sharing

@CasePathable
enum AppPath: Codable, Hashable {
  case detail(id: SyncUp.ID)
  case meeting(id: Meeting.ID, syncUpID: SyncUp.ID)
  case record(id: SyncUp.ID)
}

extension SharedReaderKey where Self == FileStorageKey<[AppPath]>.Default {
  static var path: Self {
    Self[
      .fileStorage(
        .documentsDirectory.appending(path: "path.json"),
        decode: { data in
          try JSONDecoder().decode([AppPath].self, from: data)
        },
        // TODO: write unit tests for encode logic
        encode: { path in
          try JSONEncoder().encode(
            // NB: Encode only certain paths for state restoration.
            path.filter {
              switch $0 {
              case .detail, .meeting: true
              case .record: false
              }
            }
          )
        }
      ),
      default: []
    ]
  }
}
