import Testing

@testable import OutwitGames

struct AccountScopedCacheTests {
  @Test
  func valuesRemainIsolatedByTheRequestingAccount() async {
    let cache = AccountScopedCache<String>()

    await cache.store("first account", for: 101)
    await cache.store("second account", for: 202)

    #expect(await cache.value(for: 101) == "first account")
    #expect(await cache.value(for: 202) == "second account")
    #expect(await cache.value(for: 303) == nil)

    await cache.removeValue(for: 101)

    #expect(await cache.value(for: 101) == nil)
    #expect(await cache.value(for: 202) == "second account")
  }
}
