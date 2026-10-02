public import Buffer_Linear
public import Index
public import Byte
public import Memory_Allocator_Protocol
extension Byte.Chunk {
    /// An owned, unfinalized chunk payload.
    ///
    /// `edit(_:)` lends its output span exclusively for one call. The
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
    @inlinable
    public mutating func edit<Failure: Swift.Error, R: ~Copyable>(
        _ body: (inout Swift.OutputSpan<Byte>) throws(Failure) -> R
    ) throws(Failure) -> R {
        try payload.edit(body)
    }

    /// Finalizes the committed output frontier as an owned byte chunk.
    @inlinable
    public consuming func finish() -> Byte.Chunk {
        .init(consume payload)
    }
}
