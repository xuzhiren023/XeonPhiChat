// .NET Framework 4.5 / PowerShell 5.1. Small JSON state only, never model weights.
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Security.Cryptography;

namespace PhiChat {
    public static class StateFiles {
        public static string ReadText(string path) {
            // A UI reader must allow a worker to atomically replace the pathname.
            // Windows can briefly make the pathname unavailable while two
            // ReplaceFile calls contend. Retry opening, never a partial read.
            var watch = Stopwatch.StartNew();
            while (true) {
                try {
                    using (var input = new FileStream(path, FileMode.Open, FileAccess.Read,
                                                      FileShare.ReadWrite | FileShare.Delete))
                    using (var reader = new StreamReader(input, Encoding.UTF8, true)) {
                        return reader.ReadToEnd();
                    }
                } catch (IOException error) {
                    int code = error.HResult & 0xffff;
                    if ((code != 2 && code != 32 && code != 33) || watch.ElapsedMilliseconds >= 250) throw;
                    Thread.Sleep(5);
                }
            }
        }

        public static void WriteText(string path, string text) {
            WriteText(path, text, 2000);
        }

        public static void WriteText(string path, string text, int retryMilliseconds) {
            if (retryMilliseconds < 0 || retryMilliseconds > 5000) throw new ArgumentOutOfRangeException("retryMilliseconds");
            path = Path.GetFullPath(path);
            string identity = Environment.OSVersion.Platform == PlatformID.Win32NT ? path.ToUpperInvariant() : path;
            string name;
            using (var sha = SHA256.Create()) {
                name = "PhiChat.State." + BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(identity))).Replace("-", "");
            }
            // ReplaceFile is not a transaction between competing writers.
            // Serialize publication across the UI/worker processes for this path.
            using (var gate = new Mutex(false, name)) {
                bool held = false;
                try {
                    try { held = gate.WaitOne(retryMilliseconds); }
                    catch (AbandonedMutexException) { held = true; }
                    if (!held) throw new IOException("Timed out waiting to publish JSON state file '" + path + "'.");
                    PublishText(path, text, retryMilliseconds);
                } finally { if (held) gate.ReleaseMutex(); }
            }
        }

        private static void PublishText(string path, string text, int retryMilliseconds) {
            if (Directory.Exists(path)) throw new IOException("JSON state destination is a directory: " + path);
            string temporary = path + "." + Guid.NewGuid().ToString("N") + ".new";
            bool committed = false;
            try {
                byte[] bytes = new UTF8Encoding(false).GetBytes(text);
                using (var output = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None)) {
                    output.Write(bytes, 0, bytes.Length);
                    output.Flush(true);
                }
                var watch = Stopwatch.StartNew();
                while (true) {
                    try {
                        // Keep the last complete document visible to readers.
                        // Move-Item -Force can expose a delete/rename gap and can
                        // report a misleading 'file already exists' sharing error.
                        if (File.Exists(path)) File.Replace(temporary, path, null);
                        else File.Move(temporary, path);
                        committed = true;
                        return;
                    } catch (IOException error) {
                        int code = error.HResult & 0xffff;
                        // Sharing/lock violations, a competing first writer, or
                        // destination removal between Exists and Replace. Other
                        // storage failures must remain immediate failures.
                        // ReplaceFile error 1175 leaves both names intact; a
                        // competing reader/writer can briefly block removal.
                        bool transient = code == 2 || code == 17 || code == 32 || code == 33 || code == 80 || code == 183 || code == 1175;
                        if (!transient || watch.ElapsedMilliseconds >= retryMilliseconds) {
                            throw new IOException("Cannot publish JSON state file '" + path + "' (I/O code " + code + "). " +
                                "The last complete state was retained. Check for a file lock or storage error. " + error.Message, error);
                        }
                        Thread.Sleep(40);
                    }
                }
            } finally {
                if (!committed) {
                    // Only this writer's small temporary state is disposable.
                    // Never remove the destination, another writer's temp or GGUF.
                    try { File.Delete(temporary); } catch (IOException) { } catch (UnauthorizedAccessException) { }
                }
            }
        }
    }
}
