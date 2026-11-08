public import Async_Channel
public import Byte
public import Byte_Chunk
import Synchronization

extension Byte.Channel.Writer.Send {
    /// The ownership-preserving result of any byte-channel send.
    public enum Outcome: ~Copyable {
        case sent
        case rejected(Byte.Chunk, Byte.Channel<Failure>.Error)
    }
}
