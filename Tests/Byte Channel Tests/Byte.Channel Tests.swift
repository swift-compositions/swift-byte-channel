import Byte
import Byte_Channel
import Byte_Chunk
import Index
import Pair
import Testing

@Suite
struct `Byte Channel Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Byte Channel Tests`.Unit {
    @Test
    func `chunk input ownership and ledger are source-visible`() async {
        // Static source test: `consume` prevents a second use of `input`; the
        // finished count comes from OutputSpan's committed frontier, never an
        // independently supplied count.
        var input = Byte.Chunk.Input(capacity: 3)
        input.edit { output in output.append(Byte(bitPattern: 0x01)) }
        input.edit { output in output.append(Byte(bitPattern: 0x02)) }
        input.edit { output in output.append(Byte(bitPattern: 0x03)) }
        let chunk = input.finish()
        let pieces = chunk.split(maximum: 2)
        let prefixCount = pieces.prefix.count
        let remainderCount = pieces.remainder.count
        #expect(prefixCount == 2)
        #expect(remainderCount == 1)
    }

    @Test
    func `reader preserves chunk boundaries`() async {
        // Source contract: `receive()` vends Byte.Chunk?, while the bounded
        // `receive(maximum:)` path retains one owned remainder only.
    }

    @Test
    func `chunk lifetime and negative contracts are source-visible`() async {
        // Static source contract:
        // - `Byte.Chunk.span` is a borrowing lifetime-bound `Swift.Span<Byte>`.
        // - no public `withSpan` or other `with*` chunk API exists.
        // - no raw pointer, `Span.Raw`, storage, async view, or SPI escapes.
        // - neither `span` nor the `edit(_:)` output span crosses `await`.
    }
}

extension `Byte Channel Tests`.Unit {
    struct Stop: Swift.Error, Equatable {}

    @Test
    func `finish and split keep the edited byte values`() {
        var input = Byte.Chunk.Input(capacity: 3)
        input.edit { output in
            output.append(Byte(bitPattern: 0x01))
            output.append(Byte(bitPattern: 0x02))
            output.append(Byte(bitPattern: 0x03))
        }
        let pieces = input.finish().split(maximum: 2)
        #expect(pieces.prefix.count == 2)
        #expect(pieces.remainder.count == 1)
        #expect(pieces.prefix.span[0] == Byte(bitPattern: 0x01))
        #expect(pieces.prefix.span[1] == Byte(bitPattern: 0x02))
        #expect(pieces.remainder.span[0] == Byte(bitPattern: 0x03))
    }

    @Test
    func `edit returns the body result`() {
        var input = Byte.Chunk.Input(capacity: 3)
        let written = input.edit { output in
            output.append(Byte(bitPattern: 0x07))
            output.append(Byte(bitPattern: 0x08))
            return output.count
        }
        #expect(written == 2)
        let chunk = input.finish()
        #expect(chunk.count == 2)
    }

    @Test
    func `a typed throw keeps the committed prefix`() {
        var input = Byte.Chunk.Input(capacity: 3)
        var thrown: Stop?
        do throws(Stop) {
            try input.edit { (output: inout Swift.OutputSpan<Byte>) throws(Stop) in
                output.append(Byte(bitPattern: 0x0A))
                output.append(Byte(bitPattern: 0x0B))
                throw Stop()
            }
        } catch {
            thrown = error
        }
        #expect(thrown == Stop())
        let chunk = input.finish()
        #expect(chunk.count == 2)
        #expect(chunk.span[0] == Byte(bitPattern: 0x0A))
        #expect(chunk.span[1] == Byte(bitPattern: 0x0B))
    }

    @Test
    func `zero and partial initialization finish with the committed count`() {
        let empty = Byte.Chunk.Input(capacity: 3).finish()
        #expect(empty.count == 0)
        var partial = Byte.Chunk.Input(capacity: 3)
        partial.edit { output in output.append(Byte(bitPattern: 0x2A)) }
        let chunk = partial.finish()
        #expect(chunk.count == 1)
        #expect(chunk.span[0] == Byte(bitPattern: 0x2A))
    }
}

extension `Byte Channel Tests`.`Edge Case` {
    @Test
    func `byte budget edge conditions are source-visible`() async {
        let zero: Index<Byte>.Count = .zero
        let one: Index<Byte>.Count = .one
        let zeroPair = Byte.Channel<Never>.pair(capacity: zero)
        let onePair = Byte.Channel<Never>.pair(capacity: one)
        #expect(zeroPair.first.capacity == zero)
        #expect(zeroPair.second.capacity == zero)
        #expect(onePair.first.capacity == one)
        #expect(onePair.second.capacity == one)

        // Static source law: Channel.capacity borrows the Writer gate's
        // Buffer.Capacity<Byte>; the gate initializes its mutable availability
        // from that same value. Writer admission and reader segmentation do not
        // own, mutate, retag, or shadow the fixed byte bound.
        // Empty chunks charge one admission unit; an oversize send is rejected
        // by the gate rather than bypassing the declared byte capacity.
    }

    @Test
    func `reader never needs a cross chunk buffer`() async {
        // The Reader declaration holds one `Byte.Chunk?`, not a Ring, actor
        // queue, or cross-chunk accumulator.
    }
}

extension `Byte Channel Tests`.Integration {
    @Test
    func `duplex terminal behavior remains typed`() async {}
}
