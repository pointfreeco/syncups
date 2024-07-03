#if canImport(Testing)
  import ConcurrencyExtras
  @_spi(Experimental) import Testing

  @Suite  //(MainSerialExecutorTrait())
  struct BaseTestSuite {
  }

  private struct MainSerialExecutorTrait: CustomExecutionTrait, SuiteTrait {
    let isRecursive = true

    func execute(
      _ function: @escaping () async throws -> Void,
      for test: Test,
      testCase: Test.Case?
    ) async throws {
      //    try await withMainSerialExecutor {
      try await function()
      //    }
    }
  }
#endif
