# swift-byte-channel

Use this package when two tasks need to pass bytes both ways, in owned chunks, with a limit on how many bytes can be in flight in each direction. Start from `Byte.Channel.pair(capacity:)`, which gives you two connected `Byte.Channel` endpoints, and build what you send with `Byte.Chunk.Input` or `Byte.Chunk`. If you only need to hold bytes and never send them, the `Byte Chunk` product is enough. If you pass values other than bytes, use `Async.Channel` from swift-async-channel.

## Laws

- A capacity of zero makes each direction a rendezvous, so a send waits until the peer receives. A positive capacity is a byte budget for each direction, and a send waits until the chunk's bytes fit in it.
- Budget comes back as the reader takes bytes, not when the chunk is dequeued. `Byte.Channel.Reader.receive(maximum:)` releases only the bytes it returns, so the unread rest of a chunk keeps its charge.
- The reader never joins chunks. `Byte.Channel.Reader.receive()` returns one chunk as it was sent. `Byte.Channel.Reader.receive(maximum:)` returns at most `maximum` bytes from one chunk and keeps the rest for the next call.
- A send that doesn't go through never loses the chunk. It comes back in `Byte.Channel.Writer.Send.Outcome.rejected` with the reason.
- With a positive capacity, each direction ends once. Either the writer or the peer's reader can finish or fail it, and the first call wins. Later calls do nothing. Sends waiting for budget are refused with that end.
- `Byte.Chunk.Input.edit(_:)` keeps every byte written before a throw, and `Byte.Chunk.Input.finish()` makes a chunk of exactly the bytes written so far. A chunk's `count` is its written bytes, not its allocated capacity.
