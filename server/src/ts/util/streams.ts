import Stream from "node:stream";

/**
 * A writeable that just computes the size of the stream, discarding the data
 * itself.
 */
export class SizeCounter extends Stream.Writable {
  size = 0;

  override _write(
    chunk: Uint8Array,
    _encoding: BufferEncoding,
    callback: (error?: Error | null) => void,
  ): void {
    this.size += chunk.length;
    callback();
  }

  override _writev(
    chunks: readonly { chunk: Uint8Array; encoding: BufferEncoding }[],
    callback: (error?: Error | null) => void,
  ): void {
    for (const { chunk } of chunks) {
      this.size += chunk.length;
    }
    callback();
  }

  override _final(callback: (error?: Error | null) => void): void {
    callback();
  }
}
