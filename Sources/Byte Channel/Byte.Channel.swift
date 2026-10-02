public import Async_Channel
public import Byte_Chunk
public import Byte
public import Index
public import Pair

extension Byte {
    /// A typed, bidirectional channel of owned byte chunks.
    public struct Channel<Failure: Swift.Error & Sendable>: ~Copyable, Sendable {
        public var reader: Reader
        public let writer: Writer
        let bound: Index<Byte>.Count

        public var capacity: Index<Byte>.Count {
            borrowing get { bound }
        }

        /// Creates connected endpoints with a byte capacity for each direction.
        public static func pair(capacity: Index<Byte>.Count) -> Pair<Self, Self> {
            if capacity == .zero {
                let duplexes = Async.Channel<Byte.Chunk>.Typed<Failure>.Rendezvous.Duplex.pair()
                return Pair(
                    .init(
                        reader: .init(.rendezvous(consume duplexes.first.inbound)),
                        writer: .init(.rendezvous(duplexes.first.outbound)),
                        capacity: capacity
                    ),
                    .init(
                        reader: .init(.rendezvous(consume duplexes.second.inbound)),
                        writer: .init(.rendezvous(duplexes.second.outbound)),
                        capacity: capacity
                    )
                )
            }

            var leftToRight = Async.Channel<Accepted>.Typed<Failure>.Bounded(capacity: .one)
            var rightToLeft = Async.Channel<Accepted>.Typed<Failure>.Bounded(capacity: .one)
            let leftGate = Gate(capacity: capacity)
            let rightGate = Gate(capacity: capacity)
            return Pair(
                .init(
                    reader: .init(.bounded(consume rightToLeft.receiver, rightGate)),
                    writer: .init(.bounded(leftToRight.sender, leftGate)),
                    capacity: capacity
                ),
                .init(
                    reader: .init(.bounded(consume leftToRight.receiver, leftGate)),
                    writer: .init(.bounded(rightToLeft.sender, rightGate)),
                    capacity: capacity
                )
            )
        }

        init(reader: consuming Reader, writer: Writer, capacity: Index<Byte>.Count) {
            self.reader = consume reader
            self.writer = writer
            self.bound = capacity
        }
    }
}

extension Byte.Channel {
    public typealias Error = Async.Channel<Byte.Chunk>.Typed<Failure>.Error
}
