# swift-byte-channel

Owned `Byte.Chunk` values and typed, bidirectional `Byte.Channel` endpoints.

`Byte.Chunk` owns initialized contiguous bytes in `Buffer.Linear`, offers only a
synchronous span borrow, and uses the buffer producer's owned split operation.
`Byte.Channel` wraps `Async.Channel<Byte.Chunk>.Duplex`, preserving FIFO,
directional EOF/failure, and half-close behavior while adding byte-budget
admission. It transports complete chunks only; it does not coalesce chunks or
promise zero-copy splitting.

## Key Features

- Owned, move-only byte chunks with lifetime-bound input and output views.
- Typed bidirectional channels with directional finish and failure.
- Zero-capacity rendezvous and positive-capacity byte-budget admission.
- Chunk-boundary preservation with optional single-chunk splitting.

## Quick Start

```swift
import Byte_Channel

var (left, right) = Byte.Channel<Never>.pair(
    capacity: Buffer.Capacity<Byte>(.one)
)
left.writer.finish()
_ = try await right.reader.receive()
```

## Architecture

The `Byte Chunk` product owns contiguous initialized byte storage. The
`Byte Channel` product composes those chunks with typed asynchronous endpoints
and byte-capacity admission.

## Installation

```swift
dependencies: [
    .package(
        url: "https://github.com/swift-compositions/swift-byte-channel.git",
        branch: "main"
    )
],
targets: [
    .target(
        name: "MyTarget",
        dependencies: [
            .product(name: "Byte Channel", package: "swift-byte-channel")
        ]
    )
]
```

## License

Licensed under the Apache License 2.0.
