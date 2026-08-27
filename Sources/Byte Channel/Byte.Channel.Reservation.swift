import Async_Semaphore

extension Byte.Channel {
    /// An owned byte-budget charge released exactly once as bytes are emitted.
    struct Reservation: ~Copyable, Sendable {
        let semaphore: Async.Semaphore
        var remaining: Int

        init(semaphore: Async.Semaphore, count: Int) {
            self.semaphore = semaphore
            self.remaining = count
        }

        mutating func release(_ count: Int) {
            precondition(count <= remaining)
            for _ in 0..<count { semaphore.signal() }
            remaining -= count
        }

        deinit {
            for _ in 0..<remaining { semaphore.signal() }
        }
    }
}
