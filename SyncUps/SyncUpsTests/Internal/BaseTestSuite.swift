#if canImport(Testing)
  import ConcurrencyExtras
  import Dependencies
  import Testing

  // NB: Wrap all tests in this helper to prepare the test by setting up the main serial executor
  //     and clearing out the dependencies cache.
  //
  //     Ideally we could hide these details in a testing trait, but unfortunately Swift Testing
  //     does not yet support this functionality: https://forums.swift.org/t/status-of-customexecutiontrait/73358
  func prepareTest(_ operation: () async throws -> Void) async rethrows {
    try await withMainSerialExecutor {
      try await withDependencies {
        $0 = DependencyValues()
      } operation: {
        try await operation()
      }
    }
  }
#endif
