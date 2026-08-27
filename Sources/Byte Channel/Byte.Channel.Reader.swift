import Async_Channel
import Byte_Chunk
import Index

extension Byte.Channel {
    /// The move-only inbound endpoint for one chunk at a time.
    public struct Reader: ~Copyable, Sendable {
        enum Backend: ~Copyable, Sendable {
            case bounded(Async.Channel<Accepted>.Typed<Failure>.Receiver, Gate)
            case rendezvous(Async.Channel<Byte.Chunk>.Typed<Failure>.Rendezvous.Receiver)
        }

        struct Pending: ~Copyable, Sendable {
            var chunk: Byte.Chunk
            var reservation: Reservation
        }

        var backend: Backend
        var remainder: Pending?
        var zeroRemainder: Byte.Chunk?

        init(_ backend: consuming Backend) {
            self.backend = consume backend
            self.remainder = nil
            self.zeroRemainder = nil
        }
    }
}

extension Byte.Channel.Reader {
    /// Receives exactly one producer chunk, without cross-chunk coalescing.
    public mutating func receive() async throws(Byte.Channel<Failure>.Error) -> sending Byte.Chunk?
    {
        if var pending = consume remainder {
            let count = Int(pending.chunk.count)
            pending.reservation.release(count)
            return pending.chunk
        }
        if let chunk = consume zeroRemainder { return chunk }

        switch backend {
        case .rendezvous(let receiver):
            return try await receiver.receive()

        case .bounded(let receiver, _):
            guard var accepted = try await receiver.receive() else { return nil }
            let chunk = accepted.chunk.take()
            accepted.reservation.release(Int(chunk.count))
            return chunk
        }
    }

    /// Receives at most `maximum` bytes from one producer chunk.
    public mutating func receive(
        maximum: Index<Byte>.Count
    ) async throws(Byte.Channel<Failure>.Error) -> sending Byte.Chunk? {
        if let pending = consume remainder {
            return split(consume pending, maximum: maximum)
        }
        if let chunk = consume zeroRemainder {
            return splitZero(consume chunk, maximum: maximum)
        }

        switch backend {
        case .rendezvous(let receiver):
            guard let chunk = try await receiver.receive() else { return nil }
            return splitZero(consume chunk, maximum: maximum)

        case .bounded(let receiver, _):
            guard let accepted = try await receiver.receive() else { return nil }
            let pending = Pending(
                chunk: accepted.chunk.take(),
                reservation: consume accepted.reservation
            )
            return split(consume pending, maximum: maximum)
        }
    }

    private mutating func splitZero(
        _ chunk: consuming Byte.Chunk,
        maximum: Index<Byte>.Count
    ) -> sending Byte.Chunk {
        let pieces = consume chunk.split(maximum: maximum)
        if pieces.remainder.count != .zero {
            zeroRemainder = consume pieces.remainder
        }
        return pieces.prefix
    }

    private mutating func split(
        _ pending: consuming Pending,
        maximum: Index<Byte>.Count
    ) -> sending Byte.Chunk {
        var reservation = consume pending.reservation
        let pieces = consume pending.chunk.split(maximum: maximum)
        reservation.release(Int(pieces.prefix.count))
        if pieces.remainder.count != .zero {
            remainder = Pending(chunk: consume pieces.remainder, reservation: consume reservation)
        }
        return pieces.prefix
    }

    /// Finishes the peer writer after any already-received chunk is handled.
    public func finish() {
        switch backend {
        case .rendezvous(let receiver): receiver.finish()

        case .bounded(let receiver, let gate):
            if gate.terminate(.finished) { receiver.finish() }
        }
    }

    /// Fails the peer writer with the channel's declared failure type.
    public func fail(_ failure: consuming Failure) {
        switch backend {
        case .rendezvous(let receiver): receiver.fail(consume failure)

        case .bounded(let receiver, let gate):
            if gate.terminate(.failed(failure)) { receiver.fail(consume failure) }
        }
    }
}
