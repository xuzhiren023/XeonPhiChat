using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Security.Cryptography;

namespace PhiRecovery {
    // No executable archive entries are trusted until their K1OM ELF header is checked.
    public static class Files {
        public static string Copy(string source, string destination) {
            using (var input = new FileStream(source, FileMode.Open, FileAccess.Read, FileShare.Read))
            using (var output = new FileStream(destination, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            using (var hash = SHA256.Create()) {
                var buffer = new byte[1024 * 1024]; int count;
                while ((count = input.Read(buffer, 0, buffer.Length)) != 0) {
                    output.Write(buffer, 0, count); hash.TransformBlock(buffer, 0, count, buffer, 0);
                }
                hash.TransformFinalBlock(buffer, 0, 0); output.Flush(true);
                return BitConverter.ToString(hash.Hash).Replace("-", "").ToLowerInvariant();
            }
        }
        static string Field(byte[] h, int offset, int length) {
            return Encoding.ASCII.GetString(h, offset, length).TrimEnd('\0', ' ');
        }
        static long Octal(byte[] h, int offset, int length) {
            var s = Field(h, offset, length).Trim();
            if (s.Length == 0) return 0;
            foreach (char c in s) if (c < '0' || c > '7') throw new InvalidDataException("Non-octal tar field");
            return Convert.ToInt64(s, 8);
        }
        static void ReadAll(Stream stream, byte[] bytes) {
            int n = 0;
            while (n < bytes.Length) { int got = stream.Read(bytes, n, bytes.Length - n); if (got == 0) throw new EndOfStreamException("Truncated runtime tar"); n += got; }
        }
        public static void ExtractRuntime(string archive, string destination, string commit) {
            if (Directory.Exists(destination)) throw new IOException("Runtime staging directory already exists");
            var wanted = new HashSet<string>(StringComparer.Ordinal) {
                "guard", "build-passed.txt", "llama/main", "llama/llama-bench", "llama/test-phase3-numerics"
            };
            var found = new HashSet<string>(StringComparer.Ordinal);
            var seen = new HashSet<string>(StringComparer.Ordinal);
            Directory.CreateDirectory(destination);
            using (var stream = File.OpenRead(archive)) {
                var header = new byte[512]; long total = 0;
                while (true) {
                    ReadAll(stream, header);
                    bool zero = true; foreach (byte b in header) if (b != 0) { zero = false; break; }
                    if (zero) break;
                    long sum = 0; for (int i = 0; i < 512; ++i) sum += i >= 148 && i < 156 ? 32 : header[i];
                    if (sum != Octal(header, 148, 8)) throw new InvalidDataException("Invalid tar header checksum");
                    string name = Field(header, 0, 100), prefix = Field(header, 345, 155);
                    if (prefix.Length != 0) name = prefix + "/" + name;
                    if (name.StartsWith("./", StringComparison.Ordinal)) name = name.Substring(2);
                    name = name.TrimEnd('/');
                    if (name.Length == 0 || name.StartsWith("/") || name.IndexOfAny(new [] {'\\', ':', '\r', '\n'}) >= 0)
                        throw new InvalidDataException("Unsafe runtime tar path");
                    foreach (var part in name.Split('/')) if (part == ".." || part == "." || part.Length == 0)
                        throw new InvalidDataException("Unsafe runtime tar path");
                    if (!seen.Add(name)) throw new InvalidDataException("Duplicate tar entry: " + name);
                    long size = Octal(header, 124, 12); total += size;
                    if (size < 0 || total > 256L * 1024 * 1024 || stream.Position + size > stream.Length)
                        throw new InvalidDataException("Invalid runtime tar size");
                    byte type = header[156];
                    bool regular = type == 0 || type == (byte)'0';
                    bool safeCompilerLink = type == (byte)'2' && (name == "scripts/cc" || name == "scripts/cxx") && Field(header, 157, 100) == "compiler.sh";
                    if (!regular && type != (byte)'5' && !safeCompilerLink) throw new InvalidDataException("Unsupported tar entry: " + name);
                    if (!regular && size != 0) throw new InvalidDataException("Non-file tar entry has data");
                    if (wanted.Contains(name)) {
                        if (!regular) throw new InvalidDataException("Required runtime entry is not a regular file");
                        var path = Path.Combine(destination, name.Replace('/', Path.DirectorySeparatorChar));
                        Directory.CreateDirectory(Path.GetDirectoryName(path));
                        using (var output = new FileStream(path, FileMode.CreateNew)) {
                            var buffer = new byte[65536]; long left = size;
                            while (left > 0) { int count = stream.Read(buffer, 0, (int)Math.Min(left, buffer.Length)); if (count == 0) throw new EndOfStreamException(); output.Write(buffer, 0, count); left -= count; }
                        }
                        found.Add(name);
                    } else stream.Seek(size, SeekOrigin.Current);
                    stream.Seek((512 - size % 512) % 512, SeekOrigin.Current);
                }
            }
            if (!found.SetEquals(wanted)) throw new InvalidDataException("Accepted runtime is incomplete");
            if (File.ReadAllText(Path.Combine(destination, "build-passed.txt")).Trim() != commit)
                throw new InvalidDataException("Runtime source pin does not match accepted build");
            foreach (var name in wanted) {
                if (name == "build-passed.txt") continue;
                var h = new byte[20]; using (var input = File.OpenRead(Path.Combine(destination, name.Replace('/', Path.DirectorySeparatorChar)))) ReadAll(input, h);
                if (h[0] != 127 || h[1] != 69 || h[2] != 76 || h[3] != 70 || h[4] != 2 || h[5] != 1 || h[18] != 181 || h[19] != 0)
                    throw new InvalidDataException("Not an ELF64 K1OM executable: " + name);
            }
        }
    }
}
