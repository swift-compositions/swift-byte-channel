import Cardinal
import Async_Channel
import Async_Semaphore
import Byte
import Byte_Chunk
import Index
import Synchronization

extension Byte.Channel {
    /// Positive-capacity byte admission and terminal linearization.
    final class Gate: Sendable {
        enum Terminal: Sendable {
            case finished
            case failed(Failure)
        }

        struct State: Sendable {
            var terminal: Terminal?
        }

        let capacity: Index<Byte>.Count
        let turn: Async.Semaphore
        let bytes: Async.Semaphore
        let state: Mutex<State>

        init(capacity: Index<Byte>.Count) {
            precondition(capacity != .zero)
            self.capacity = capacity
            self.turn = Async.Semaphore(capacity: 1)
            self.bytes = Async.Semaphore(capacity: Int(clamping: capacity))
            self.state = Mutex(State(terminal: nil))
        }

        func reserve(_ count: Index<Byte>.Count) async throws(Error) -> Reservation {
            precondition(count <= capacity, "chunk exceeds channel byte capacity")
            do {
                try await turn.wait()
            } catch {
                throw terminalError(fallback: error)
            }

            var acquired = 0
            do {
                while acquired < Int(clamping: count) {
                    try await bytes.wait()
                    acquired += 1
                }
            } catch {
                while acquired > 0 {
                    bytes.signal()
                    acquired -= 1
                }
                turn.signal()
                throw terminalError(fallback: error)
            }

            let terminal = state.withLock { $0.terminal }
            turn.signal()
            if let terminal {
                while acquired > 0 {
                    bytes.signal()
                    acquired -= 1
                }
                throw Self.error(terminal)
            }
            return Reservation(semaphore: bytes, count: Int(clamping: count))
        }

        func terminate(_ terminal: Terminal) -> Bool {
            let installed = state.withLock { state in
                guard state.terminal == nil else { return false }
                state.terminal = terminal
                return true
            }
            if installed {
                turn.shutdown()
                bytes.shutdown()
            }
            return installed
        }

        private func terminalError(
            fallback: Async.Semaphore.Error
        ) -> Byte.Channel<Failure>.Error {
            if let terminal = state.withLock({ $0.terminal }) {
                return Self.error(terminal)
            }
            switch fallback {
            case .cancelled: return .cancelled
            case .shutdown: return .closed
            case .timeout: return .cancelled
            }
        }

        private static func error(
            _ terminal: Terminal
        ) -> Byte.Channel<Failure>.Error {
            switch terminal {
            case .finished: return .finished
            case .failed(let failure): return .failed(failure)
            }
        }
    }
}
