// .NET Framework 4.5 / Windows PowerShell 5.1 compatible.
// The networking callback stores only the latest byte count. No PowerShell
// runspace, event queue or per-chunk objects are retained by this observer.
using System.Net;
using System.Threading;

namespace PhiChat {
    public sealed class DownloadProgressCounter {
        private long receivedBytes;

        public long ReceivedBytes {
            get { return Interlocked.Read(ref receivedBytes); }
        }

        public DownloadProgressChangedEventHandler Handler {
            get { return OnProgress; }
        }

        private void OnProgress(object sender, DownloadProgressChangedEventArgs progress) {
            Interlocked.Exchange(ref receivedBytes, progress.BytesReceived);
        }
    }
}
