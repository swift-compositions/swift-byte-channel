import Byte
import Byte_Chunk
import Synchronization

extension Byte.Channel {
    /// A positively admitted chunk and its still-owned byte charge.
    struct Accepted: ~Copyable, Sendable {
        final class Slot: Sendable {
            let chunk: Mutex<Byte.Chunk?>

            init(_ chunk: consuming Byte.Chunk) {
                self.chunk = Mutex(consume chunk)
            }

            func take() -> sending Byte.Chunk {
                chunk.withLock { $0.take()! }
            }
        }

        let chunk: Slot
        var reservation: Reservation

        init(chunk: Slot, reservation: consuming Reservation) {
            self.chunk = chunk
            self.reservation = consume reservation
        }
    }
}
