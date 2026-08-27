public import Buffer_Linear
public import Byte
public import Index

extension Byte {
    /// An owned, contiguous, initialized sequence of bytes.
    ///
    /// A chunk is move-only. Its backing allocation is private and is exposed
    /// only through a lifetime-bound span borrow.
    @frozen
    public struct Chunk: ~Copyable, Sendable {
        @usableFromInline
        var payload: Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Byte>>.Linear

        /// Creates a chunk by initializing its payload through an output span.
        @inlinable
        public init<Failure: Swift.Error>(
            capacity: Index<Byte>.Count,
            initializingWith initialize: (inout Swift.OutputSpan<Byte>) throws(Failure) -> Void
        ) throws(Failure) {
            self.payload = try .init(capacity: capacity, initializingWith: initialize)
        }

        @usableFromInline
        init(
            _ payload:
                consuming Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Byte>>.Linear
        ) {
            self.payload = consume payload
        }
    }
}

extension Byte.Chunk {
    /// The initialized byte count, rather than the allocation capacity.
    @inlinable
    public var count: Index<Byte>.Count { payload.count }

    /// A lifetime-bound view of the initialized bytes.
    ///
    /// The view cannot outlive this chunk and never exposes its backing
    /// storage. Its extent is the payload's initialized prefix.
    @inlinable
    public var span: Swift.Span<Byte> {
        @_lifetime(borrow self)
        borrowing get {
            payload.span
        }
    }

    /// Consumes this chunk into an owned prefix and owned remainder.
    ///
    /// This forwards to `Buffer.Linear.split(maximum:)`; it relocates bytes
    /// into distinct allocations and deliberately makes no zero-copy claim.
    @inlinable
    public consuming func split(maximum: Index<Byte>.Count) -> Split {
        let parts = consume payload.split(maximum: maximum)
        return .init(prefix: .init(consume parts.prefix), remainder: .init(consume parts.remainder))
    }
}

extension Byte.Chunk {
    /// The two independently owned pieces of a split chunk.
    @frozen
    public struct Split: ~Copyable, Sendable {
        public let prefix: Byte.Chunk
        public let remainder: Byte.Chunk

        @inlinable
        init(prefix: consuming Byte.Chunk, remainder: consuming Byte.Chunk) {
            self.prefix = consume prefix
            self.remainder = consume remainder
        }
    }
}
