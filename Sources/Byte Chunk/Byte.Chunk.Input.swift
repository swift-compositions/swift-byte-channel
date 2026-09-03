extension Byte.Chunk {
    /// An owned, unfinalized chunk payload.
    ///
    /// Its output span is exclusive and lifetime-bound to this input. The
    /// underlying linear buffer owns the initialization ledger; `finish()`
    /// transfers that finalized ledger into a chunk.
    @frozen
    public struct Input: ~Copyable, Sendable {
        @usableFromInline
        var payload: Buffer<Storage::Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Byte>>.Linear

        /// Creates an empty input with at least the requested byte capacity.
        @inlinable
        public init(capacity: Index<Byte>.Count) {
            self.payload = .init(minimumCapacity: capacity)
        }
    }
}

extension Byte.Chunk.Input {
    /// An exclusive output view whose committed frontier is the input ledger.
    @inlinable
    public var outputSpan: Swift.OutputSpan<Byte> {
        @_lifetime(&self)
        _modify {
            yield &payload.outputSpan
        }
        @_lifetime(borrow self)
        _read {
            yield payload.outputSpan
        }
    }

    /// Finalizes the committed output frontier as an owned byte chunk.
    @inlinable
    public consuming func finish() -> Byte.Chunk {
        .init(consume payload)
    }
}
