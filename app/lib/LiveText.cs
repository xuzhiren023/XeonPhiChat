// .NET 4.5 / Windows PowerShell 5.1 compatible. No PowerShell callbacks on worker threads.
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace PhiChat {
    public sealed class LiveCapture {
        private long firstByteMilliseconds = -1;
        private long bytesWritten;
        public long FirstByteMilliseconds { get { return Interlocked.Read(ref firstByteMilliseconds); } }
        public long BytesWritten { get { return Interlocked.Read(ref bytesWritten); } }

        public async Task CopyAsync(Stream input, Stream output) {
            var watch = Stopwatch.StartNew();
            var buffer = new byte[4096];
            int count;
            while ((count = await input.ReadAsync(buffer, 0, buffer.Length).ConfigureAwait(false)) != 0) {
                await output.WriteAsync(buffer, 0, count).ConfigureAwait(false);
                // WriteThrough alone does not flush FileStream's managed buffer.
                // Flush each received piece, even without a newline or a full buffer.
                await output.FlushAsync().ConfigureAwait(false);
                Interlocked.CompareExchange(ref firstByteMilliseconds, watch.ElapsedMilliseconds, -1);
                Interlocked.Add(ref bytesWritten, count);
            }
        }
    }

    public sealed class Utf8Tail {
        private long position;
        private readonly Decoder decoder = new UTF8Encoding(false).GetDecoder();
        private readonly byte[] bytes = new byte[4096];
        private readonly char[] chars = new char[8192];
        private bool finished;

        // Keep decoder state across reads: a UTF-8 character can span SSH chunks.
        // Reopen the file so closing the UI never prevents prompt/output cleanup.
        public string Read(string path, bool complete) {
            if (finished || !File.Exists(path)) return String.Empty;
            var result = new StringBuilder();
            using (var file = new FileStream(path, FileMode.Open, FileAccess.Read,
                                             FileShare.ReadWrite | FileShare.Delete)) {
                if (file.Length < position) throw new IOException("Response file was truncated during streaming.");
                file.Position = position;
                int count;
                while ((count = file.Read(bytes, 0, bytes.Length)) != 0) {
                    position += count;
                    result.Append(chars, 0, decoder.GetChars(bytes, 0, count, chars, 0, false));
                }
            }
            if (complete) {
                result.Append(chars, 0, decoder.GetChars(bytes, 0, 0, chars, 0, true));
                finished = true;
            }
            return result.ToString();
        }
    }
}

namespace PhiChat {
    // Dedicated C# reader avoids PowerShell callbacks/events on worker threads.
    // Every telemetry record contains only an enum and three bounded integers.
    public sealed class NativeProgress {
        public string Stage { get; set; }
        public long Consumed { get; set; }
        public long AvailableKiB { get; set; }
        public long AdditionalKiB { get; set; }
        public double SampleSeconds { get; set; }
        public double PrefillSeconds { get; set; }
    }
    public sealed class DiagnosticCapture {
        private readonly object gate = new object();
        private NativeProgress latest;
        public NativeProgress Snapshot { get { lock (gate) { return latest; } } }
        public async Task<string> ReadAsync(StreamReader input) {
            var watch=Stopwatch.StartNew();
            var text=new StringBuilder();
            double prefillStart=-1;
            string line;
            while ((line=await input.ReadLineAsync().ConfigureAwait(false)) != null) {
                var match=System.Text.RegularExpressions.Regex.Match(line,
                    @"^PHICHAT_PROGRESS (init|check|vision|prefill) ([0-9]{1,9}) ([0-9]{1,12}) ([0-9]{1,12})$");
                if (!match.Success) { text.AppendLine(line); continue; }
                double now=watch.Elapsed.TotalSeconds;
                string stage=match.Groups[1].Value;
                if (stage=="prefill" && prefillStart<0) prefillStart=now;
                var sample=new NativeProgress { Stage=stage,
                    Consumed=Int64.Parse(match.Groups[2].Value),
                    AvailableKiB=Int64.Parse(match.Groups[3].Value),
                    AdditionalKiB=Int64.Parse(match.Groups[4].Value),
                    SampleSeconds=now, PrefillSeconds=prefillStart<0 ? 0 : now-prefillStart };
                lock (gate) { latest=sample; }
            }
            return text.ToString();
        }
    }
    public sealed class TextRate {
        private long characters;
        private double first=-1;
        private readonly System.Collections.Generic.Queue<double[]> samples=new System.Collections.Generic.Queue<double[]>();
        // A display estimate, not tokenizer counts, byte counts or SSH chunks.
        public double? Add(string piece, double seconds) {
            if (piece.Length>0) {
                if (first<0) first=seconds;
                for (int i=0; i<piece.Length; i++) {
                    if (Char.IsHighSurrogate(piece[i]) && i+1<piece.Length && Char.IsLowSurrogate(piece[i+1])) i++;
                    characters++;
                }
            }
            if (first<0) return null;
            samples.Enqueue(new double[]{seconds,characters});
            while (samples.Count>1 && seconds-samples.Peek()[0]>10) samples.Dequeue();
            var oldest=samples.Peek();
            double elapsed=seconds-oldest[0];
            if (elapsed<1) return null;
            return Math.Max(0,(characters-oldest[1])/4.0/elapsed);
        }
        public double EstimatedTokens { get { return characters/4.0; } }
    }
}
