import Async_Channel
import Byte_Chunk

extension Byte.Channel {
    /// The outbound endpoint for owned byte chunks.
    public struct Writer: Sendable {
        enum Backend: Sendable {
            case bounded(Async.Channel<Accepted>.Typed<Failure>.Sender, Gate)
            case rendezvous(Async.Channel<Byte.Chunk>.Typed<Failure>.Rendezvous.Sender)
        }

        let backend: Backend

        init(_ backend: Backend) {
            self.backend = backend
        }
    }
}

extension Byte.Channel.Writer {
    /// Sends one whole chunk while preserving ownership on rejection.
    public func send(_ chunk: consuming sending Byte.Chunk) async -> Send.Outcome {
        switch backend {
        case .rendezvous(let sender):
            switch await sender.send(consume chunk) {
            case .sent:
                return .sent

            case .rejected(let rejected, let error):
                return .rejected(consume rejected, error)
            }

        case .bounded(let sender, let gate):
            let slot = Accepted.Slot(consume chunk)
            do throws(Byte.Channel<Failure>.Error) {
                let reservation = try await gate.reserve(slot.chunk.withLock { $0!.count })
                try await sender.send(Accepted(chunk: slot, reservation: consume reservation))
                return .sent
            } catch {
                return .rejected(slot.take(), error)
            }
        }
    }

    /// Half-closes this outbound direction while inbound remains drainable.
    public func finish() {
        switch backend {
        case .rendezvous(let sender): sender.finish()

        case .bounded(let sender, let gate):
            if gate.terminate(.finished) { sender.finish() }
        }
    }

    /// Fails this outbound direction after its accepted chunks drain.
    public func fail(_ failure: consuming Failure) {
        switch backend {
        case .rendezvous(let sender): sender.fail(consume failure)

        case .bounded(let sender, let gate):
            if gate.terminate(.failed(failure)) { sender.fail(consume failure) }
        }
    }
}

extension Byte.Channel.Writer {
    /// Namespace for ownership-preserving send results.
    public enum Send {}
}

extension Byte.Channel.Writer.Send {
    /// The ownership-preserving result of any byte-channel send.
    public enum Outcome: ~Copyable {
        case sent
        case rejected(Byte.Chunk, Byte.Channel<Failure>.Error)
    }
}
