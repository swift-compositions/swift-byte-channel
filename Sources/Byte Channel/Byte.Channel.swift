public import Async_Channel
public import Buffer_Protocol
public import Byte_Chunk
public import Byte
public import Index

extension Byte {
    /// A typed, bidirectional channel of owned byte chunks.
    public struct Channel<Failure: Swift.Error & Sendable>: ~Copyable, Sendable {
        public var reader: Reader
        public let writer: Writer
        let bound: Buffer.Capacity<Byte>

        public var capacity: Buffer.Capacity<Byte> {
            borrowing get { bound }
        }

        /// Creates connected endpoints with a byte capacity for each direction.
        public static func pair(capacity: Buffer.Capacity<Byte>) -> (Self, Self) {
            if capacity.count == .zero {
                var duplexes = Async.Channel<Byte.Chunk>.Typed<Failure>.Rendezvous.Duplex.pair()
                return (
                    .init(
                        reader: .init(.rendezvous(consume duplexes.0.inbound)),
                        writer: .init(.rendezvous(duplexes.0.outbound)),
                        capacity: capacity
                    ),
                    .init(
                        reader: .init(.rendezvous(consume duplexes.1.inbound)),
                        writer: .init(.rendezvous(duplexes.1.outbound)),
                        capacity: capacity
                    )
                )
            }

            var leftToRight = Async.Channel<Accepted>.Typed<Failure>.Bounded(capacity: .one)
            var rightToLeft = Async.Channel<Accepted>.Typed<Failure>.Bounded(capacity: .one)
            let leftGate = Gate(capacity: capacity)
            let rightGate = Gate(capacity: capacity)
            return (
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

        init(reader: consuming Reader, writer: Writer, capacity: Buffer.Capacity<Byte>) {
            self.reader = consume reader
            self.writer = writer
            self.bound = capacity
        }
    }
}

extension Byte.Channel {
    public typealias Error = Async.Channel<Byte.Chunk>.Typed<Failure>.Error
}
