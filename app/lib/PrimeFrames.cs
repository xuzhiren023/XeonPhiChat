using System;
using System.Collections.Concurrent;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace PhiChat {
    public sealed class PrimeFrame {
        public string Id { get; internal set; }
        public string Kind { get; internal set; }
        public byte[] Data { get; internal set; }
        public string Text { get { return new UTF8Encoding(false, true).GetString(Data); } }
    }
    // Control frames have explicit lengths; model text is never a control line.
    public sealed class PrimeFrames : IDisposable {
        readonly BlockingCollection<PrimeFrame> frames = new BlockingCollection<PrimeFrame>(128);
        readonly Stream input;
        readonly Task reader;
        volatile bool stop;
        volatile bool complete;
        volatile string error = "";
        public bool Complete { get { return complete; } }
        public string Error { get { return error; } }
        public PrimeFrames(Stream input) {
            this.input = input;
            reader = Task.Factory.StartNew(Read, CancellationToken.None, TaskCreationOptions.LongRunning, TaskScheduler.Default);
        }
        public PrimeFrame Pop() {
            PrimeFrame f;
            return frames.TryTake(out f) ? f : null;
        }
        void Read() {
            try {
                while (!stop) {
                    var header = new StringBuilder();
                    int ch = input.ReadByte();
                    if (ch < 0) break;
                    while (ch != '\n') {
                        if (ch < 32 || ch > 126 || header.Length >= 128) throw new InvalidDataException("Invalid priming frame header");
                        header.Append((char)ch);
                        ch = input.ReadByte();
                    }
                    string[] fields = header.ToString().Split(' ');
                    int length;
                    if (fields.Length != 4 || fields[0] != "PHIP1" || fields[1].Length != 32 ||
                        !Int32.TryParse(fields[3], out length) || length < 0 || length > 32768)
                        throw new InvalidDataException("Invalid priming frame dimensions");
                    foreach (char c in fields[1]) if (!(c >= '0' && c <= '9') && !(c >= 'a' && c <= 'f')) throw new InvalidDataException("Invalid request identity");
                    switch (fields[2]) {
                        case "READY": case "ACK": case "STAGE": case "COUNT": case "ACCEPTED": case "REJECTED": case "DONE":
                            if (length > 8192) throw new InvalidDataException("Oversized control frame");
                            break;
                        case "TEXT": break;
                        default: throw new InvalidDataException("Unknown priming frame type");
                    }
                    var data = new byte[length];
                    for (int offset = 0; offset < length;) {
                        int n = input.Read(data, offset, length-offset);
                        if (n == 0) throw new EndOfStreamException("Truncated priming frame");
                        offset += n;
                    }
                    var f = new PrimeFrame { Id=fields[1], Kind=fields[2], Data=data };
                    while (!stop && !frames.TryAdd(f, 100)) {}
                }
            } catch (Exception e) { if (!stop) error = e.Message; }
            finally { complete = true; }
        }
        public void Dispose() { stop = true; }
    }
}
