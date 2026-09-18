actor AccountScopedCache<Value: Sendable> {
  private var values: [Int: Value] = [:]

  func value(for accountID: Int) -> Value? {
    values[accountID]
  }

  func store(_ value: Value, for accountID: Int) {
    values[accountID] = value
  }

  func removeValue(for accountID: Int) {
    values.removeValue(forKey: accountID)
  }

  func clear() {
    values.removeAll()
  }
}
