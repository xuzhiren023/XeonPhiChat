// .NET Framework 4, Windows x64. MPSS supplies uSCIF.dll; never redistribute it.
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace PhiChat.Scif {
    // Fixed 64-byte, little-endian records. All positions/sizes are 64-bit.
    public sealed class Frame {
        public ulong Tag, Position, Bytes, Value;
        public string Nonce = "";
        public byte[] Encode() {
            byte[] b = new byte[64];
            Array.Copy(BitConverter.GetBytes(Tag), 0, b, 0, 8);
            Array.Copy(BitConverter.GetBytes(Position), 0, b, 8, 8);
            Array.Copy(BitConverter.GetBytes(Bytes), 0, b, 16, 8);
            Array.Copy(BitConverter.GetBytes(Value), 0, b, 24, 8);
            if (Nonce.Length == 32) Encoding.ASCII.GetBytes(Nonce, 0, 32, b, 32);
            return b;
        }
        public static Frame Decode(byte[] b) {
            if (b.Length != 64) throw new InvalidDataException("Invalid SCIF frame length.");
            return new Frame { Tag=BitConverter.ToUInt64(b,0), Position=BitConverter.ToUInt64(b,8),
                Bytes=BitConverter.ToUInt64(b,16), Value=BitConverter.ToUInt64(b,24), Nonce=Encoding.ASCII.GetString(b,32,32) };
        }
        public static void CheckWindow(Frame f, ulong position, ulong total) {
            ulong count=Math.Min(67108864UL,total-position);
            if (f.Tag != 3 || f.Position != position || f.Bytes != count || f.Value > long.MaxValue-67108864UL || (f.Value & 4095) != 0)
                throw new InvalidDataException("Invalid SCIF window or file position.");
        }
    }
    internal static class Native {
        const string Dll="uSCIF.dll";
        [StructLayout(LayoutKind.Sequential)] internal struct Port { public ushort Node, Number; }
        [StructLayout(LayoutKind.Sequential)] internal struct Poll { public IntPtr Endpoint; public short Events, Returned; }
        [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] internal static extern IntPtr scif_open();
        [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] internal static extern int scif_close(IntPtr e);
        [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] internal static extern int scif_bind(IntPtr e, ushort port);
        [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] internal static extern int scif_listen(IntPtr e, int backlog);
        [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] internal static extern int scif_accept(IntPtr e, out Port peer, out IntPtr accepted, int flags);
        [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] internal static extern int scif_get_nodeIDs([Out] ushort[] nodes, int length, out ushort self);
        [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] internal static extern int scif_poll(ref Poll p, uint count, int timeout);
        [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] internal static extern int scif_send(IntPtr e, IntPtr data, int length, int flags);
        [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] internal static extern int scif_recv(IntPtr e, IntPtr data, int length, int flags);
        [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] internal static extern long scif_register(IntPtr e, IntPtr data, UIntPtr length, long offset, int prot, int flags);
        [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] internal static extern int scif_unregister(IntPtr e, long offset, UIntPtr length);
        [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] internal static extern int scif_writeto(IntPtr e, long local, UIntPtr length, long remote, int flags);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] internal static extern IntPtr LoadLibraryEx(string path, IntPtr file, uint flags);
        [DllImport("kernel32.dll", SetLastError=true)] internal static extern IntPtr VirtualAlloc(IntPtr address, UIntPtr length, uint type, uint protection);
        [DllImport("kernel32.dll")] internal static extern bool VirtualFree(IntPtr address, UIntPtr length, uint type);
        [DllImport("kernel32.dll", SetLastError=true)] internal static extern bool ReadFile(SafeFileHandle file, IntPtr buffer, uint count, out uint read, IntPtr overlapped);
    }
    internal static class Program {
        const int Window=64*1024*1024;
        static readonly IntPtr Invalid=new IntPtr(-1);
        static string statusPath;
        static int port, node;
        static readonly Stopwatch watch=Stopwatch.StartNew();
        static void Status(string state, ulong bytes, string category) {
            if (statusPath == null) return;
            string json=String.Format(System.Globalization.CultureInfo.InvariantCulture,
                "{{\"state\":\"{0}\",\"bytes\":{1},\"port\":{2},\"node\":{3},\"category\":\"{4}\"}}",state,bytes,port,node,category);
            string part=statusPath+".tmp";
            File.WriteAllText(part,json,new UTF8Encoding(false));
            if (File.Exists(statusPath)) File.Replace(part,statusPath,null); else File.Move(part,statusPath);
        }
        static void Wait(IntPtr e, short events) {
            double deadline=watch.Elapsed.TotalSeconds+30;
            for (;;) {
                if (watch.Elapsed.TotalSeconds > deadline || watch.Elapsed.TotalSeconds > 900) throw new IOException("SCIF transfer timed out.");
                Native.Poll p=new Native.Poll { Endpoint=e, Events=events };
                int r=Native.scif_poll(ref p,1,100);
                if (r < 0 || (p.Returned & 0x38) != 0) throw new IOException("SCIF endpoint disconnected.");
                if (r > 0 && (p.Returned & events) != 0) return;
            }
        }
        static void TransferFrame(IntPtr e, byte[] bytes, bool send) {
            GCHandle h=GCHandle.Alloc(bytes,GCHandleType.Pinned);
            try {
                int offset=0;
                while (offset < bytes.Length) {
                    Wait(e, (short)(send ? 4 : 1));
                    IntPtr p=IntPtr.Add(h.AddrOfPinnedObject(),offset);
                    int n=send ? Native.scif_send(e,p,bytes.Length-offset,0) : Native.scif_recv(e,p,bytes.Length-offset,0);
                    if (n <= 0) throw new IOException("SCIF control message failed.");
                    offset+=n;
                }
            } finally { h.Free(); }
        }
        static void Send(IntPtr e, Frame f) { TransferFrame(e,f.Encode(),true); }
        static Frame Receive(IntPtr e) { byte[] b=new byte[64]; TransferFrame(e,b,false); return Frame.Decode(b); }
        public static int Main(string[] args) {
            IntPtr listener=Invalid, endpoint=Invalid, buffer=IntPtr.Zero;
            long registered=-1; ulong copied=0;
            try {
                if (args.Length != 4 || !Environment.Is64BitProcess || !BitConverter.IsLittleEndian)
                    throw new InvalidDataException("Expected source, bytes, nonce and progress path in an x64 process.");
                statusPath=args[3]; ulong total=UInt64.Parse(args[1]);
                if (total == 0 || total > long.MaxValue || !System.Text.RegularExpressions.Regex.IsMatch(args[2],"^[a-f0-9]{32}$"))
                    throw new InvalidDataException("Invalid file size or transfer nonce.");
                // Explicit System32 load prevents DLL search through the download folder.
                string dll=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),"uSCIF.dll");
                if (Native.LoadLibraryEx(dll,IntPtr.Zero,8) == IntPtr.Zero) throw new IOException("MPSS SCIF library unavailable.");
                ushort[] nodes=new ushort[256]; ushort self;
                int count=Native.scif_get_nodeIDs(nodes,nodes.Length,out self);
                if (count < 1 || count > nodes.Length || self != 0) throw new IOException("No SCIF card nodes available.");
                listener=Native.scif_open();
                if (listener == Invalid) throw new IOException("SCIF open failed.");
                port=Native.scif_bind(listener,0);
                if (port < 1088 || port > 65535 || Native.scif_listen(listener,1) != 0) throw new IOException("SCIF listen failed.");
                Status("waiting",0,""); Wait(listener,1);
                Native.Port peer;
                if (Native.scif_accept(listener,out peer,out endpoint,0) != 0) throw new IOException("SCIF accept failed.");
                node=peer.Node;
                if (node == 0 || Array.IndexOf(nodes,(ushort)node,0,count) < 0) throw new InvalidDataException("Unexpected SCIF peer.");
                // The receiver is started only through pinned SSH on the chosen card.
                // Its nonce binds that card to this ephemeral SCIF connection, with no assumed card index.
                Frame hello=Receive(endpoint);
                if (hello.Tag != 1 || hello.Position != 0 || hello.Bytes != total || hello.Value != Window || hello.Nonce != args[2])
                    throw new InvalidDataException("SCIF receiver identity or protocol mismatch.");
                using (FileStream input=File.Open(args[0],FileMode.Open,FileAccess.Read,FileShare.Read)) {
                    if ((ulong)input.Length != total) throw new InvalidDataException("Source file size changed.");
                    SafeFileHandle sourceHandle=input.SafeFileHandle;
                    buffer=Native.VirtualAlloc(IntPtr.Zero,new UIntPtr(Window),0x3000,4);
                    if (buffer == IntPtr.Zero) throw new IOException("Cannot allocate SCIF staging window.");
                    registered=Native.scif_register(endpoint,buffer,new UIntPtr(Window),0,1,0);
                    if (registered < 0) throw new IOException("Cannot register SCIF staging window.");
                    Send(endpoint,new Frame { Tag=2, Bytes=total, Value=Window, Nonce=args[2] });
                    while (copied < total) {
                        Frame f=Receive(endpoint); Frame.CheckWindow(f,copied,total);
                        uint wanted=(uint)f.Bytes, read=0;
                        while (read < wanted) {
                            uint n;
                            if (!Native.ReadFile(sourceHandle,IntPtr.Add(buffer,(int)read),wanted-read,out n,IntPtr.Zero) || n == 0)
                                throw new InvalidDataException("Cannot read the complete Windows file.");
                            read+=n;
                        }
                        // Pad only the final cache line; receiver truncates to the exact original size.
                        int padded=(int)((wanted+63U)&~63U);
                        for (int i=(int)wanted; i<padded; i++) Marshal.WriteByte(buffer,i,0);
                        // SCIF_RMA_SYNC waits for DMA completion before the mapping can be recycled.
                        // No SCIF_RMA_USECPU: bulk data goes through the card's DMA engine.
                        if (Native.scif_writeto(endpoint,registered,new UIntPtr((uint)padded),(long)f.Value,4) != 0)
                            throw new IOException("SCIF DMA write failed.");
                        Send(endpoint,new Frame { Tag=4, Position=copied, Bytes=f.Bytes });
                        copied+=f.Bytes; Status("copying",copied,"");
                    }
                    Frame done=Receive(endpoint);
                    if (done.Tag != 5 || done.Position != total || done.Bytes != total) throw new InvalidDataException("SCIF completion was not acknowledged.");
                }
                Status("complete",copied,"");
                Console.WriteLine("SCIF DMA completed: {0} bytes, node {1}, {2:F3} seconds.",copied,node,watch.Elapsed.TotalSeconds);
                return 0;
            } catch (Exception ex) {
                bool fatal=ex is InvalidDataException || ex is UnauthorizedAccessException;
                try { Status("failed",copied,fatal ? "fatal" : "transport"); } catch { }
                Console.Error.WriteLine(ex.Message); return fatal ? 43 : 2;
            } finally {
                if (registered >= 0 && endpoint != Invalid) Native.scif_unregister(endpoint,registered,new UIntPtr(Window));
                if (endpoint != Invalid) Native.scif_close(endpoint);
                if (listener != Invalid) Native.scif_close(listener);
                if (buffer != IntPtr.Zero) Native.VirtualFree(buffer,UIntPtr.Zero,0x8000);
            }
        }
    }
}
