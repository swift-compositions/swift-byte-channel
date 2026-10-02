public import Byte
public import Async_Channel
public import Byte_Chunk
public import Index
import Cardinal

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
        if var pending = remainder.take() {
            pending.reservation.release(Int(clamping: pending.chunk.count))
            return pending.chunk
        }
        if let chunk = zeroRemainder.take() { return chunk }

        switch backend {
        case .rendezvous(let receiver):
            return try await receiver.receive()

        case .bounded(let receiver, _):
            guard var accepted = try await receiver.receive() else { return nil }
            let chunk = accepted.chunk.take()
            accepted.reservation.release(Int(clamping: chunk.count))
            return chunk
        }
    }

    enum Received: ~Copyable {
        case unreserved(Byte.Chunk)
        case reserved(Pending)
    }

    /// Receives at most `maximum` bytes from one producer chunk.
    public mutating func receive(
        maximum: Index<Byte>.Count
    ) async throws(Byte.Channel<Failure>.Error) -> sending Byte.Chunk? {
        if let pending = remainder.take() {
            return split(pending, maximum: maximum)
        }
        if let chunk = zeroRemainder.take() {
            return splitZero(chunk, maximum: maximum)
        }

        let received: Received
        switch backend {
        case .rendezvous(let receiver):
            guard let chunk = try await receiver.receive() else { return nil }
            received = .unreserved(chunk)

        case .bounded(let receiver, _):
            guard let accepted = try await receiver.receive() else { return nil }
            received = .reserved(Pending(chunk: accepted.chunk.take(), reservation: consume accepted.reservation))
        }
        switch consume received {
        case .unreserved(let chunk): return splitZero(chunk, maximum: maximum)
        case .reserved(let pending): return split(pending, maximum: maximum)
        }
    }

    private mutating func splitZero(
        _ chunk: consuming Byte.Chunk,
        maximum: Index<Byte>.Count
    ) -> sending Byte.Chunk {
        let pieces = chunk.split(maximum: maximum)
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
        let pieces = pending.chunk.split(maximum: maximum)
        reservation.release(Int(clamping: pieces.prefix.count))
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
    public func fail(_ failure: Failure) {
        switch backend {
        case .rendezvous(let receiver): receiver.fail(failure)

        case .bounded(let receiver, let gate):
            if gate.terminate(.failed(failure)) { receiver.fail(failure) }
        }
    }
}
