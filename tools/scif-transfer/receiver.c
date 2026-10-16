/* Phi Chat SCIF DMA receiver. Build against the installed MPSS SDK's scif.h.
 * No host Ethernet/IP dependency. The card connects to the SCIF host (node 0).
 * DMA lands in file-backed pages: no second 64 MiB copy on the KNC cores. */
#define _GNU_SOURCE
#define _FILE_OFFSET_BITS 64
#include <scif.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <signal.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <poll.h>
#include <unistd.h>
#include <errno.h>

#define WINDOW (64UL*1024*1024)
typedef struct { uint64_t tag, position, bytes, value; char nonce[32]; } frame;
typedef char frame_must_be_64_bytes[sizeof(frame)==64 ? 1 : -1];
static const char *part;
static char pid_path[256];
static int created;
static int pid_owned;
static int success;

static void cleanup(void) {
    if (created && !success) unlink(part);
    if (pid_owned) unlink(pid_path);
}
static void stopped(int sig) { (void)sig; cleanup(); _exit(2); }
static void fail(const char *message, int fatal) {
    fprintf(stderr,"%s: %s (%s)\n",fatal ? "fatal" : "transport",message,strerror(errno));
    exit(fatal ? 43 : 2);
}
static int hex32(const char *s) {
    size_t i; if (strlen(s)!=32) return 0;
    for (i=0;i<32;i++) if (!((s[i]>='0'&&s[i]<='9')||(s[i]>='a'&&s[i]<='f'))) return 0;
    return 1;
}
static int valid_path(const char *s) {
    size_t n=strlen(s),i;
    if (n<12 || n>240 || strcmp(s+n-5,".part") || strstr(s,"..") || strstr(s,"//")) return 0;
    if (strncmp(s,"/root/knc-phase3-run-",21) && strncmp(s,"/root/knc-chat-",15) &&
        strncmp(s,"/root/knc-modern-",17) && strncmp(s,"/root/knc-gcc-",14)) return 0;
    for (i=0;i<n;i++) if (!(isalnum((unsigned char)s[i]) || s[i]=='/' || s[i]=='-' || s[i]=='_' || s[i]=='.')) return 0;
    return 1;
}
static void health(void) {
    static char pending[32]; static size_t used;
    struct pollfd p={0,POLLIN,0}; char b[64]; ssize_t n,i;
    int r=poll(&p,1,0);
    if (r<0 && errno==EINTR) return;
    if (r<0) fail("health pipe",0);
    if (r && (p.revents&(POLLIN|POLLHUP|POLLERR))) {
        n=read(0,b,sizeof b);
        if (n<=0) fail("controller disconnected",0);
        for (i=0;i<n;i++) {
            if (b[i]=='\n') {
                pending[used]=0;
                if (strcmp(pending,"health-ok")) fail("invalid heartbeat",1);
                used=0; alarm(20);
            } else if (b[i]!='\r') {
                if (used>=sizeof(pending)-1) fail("invalid heartbeat",1);
                pending[used++]=b[i];
            }
        }
    }
}
static void ready(scif_epd_t e, short event) {
    for (;;) {
        struct scif_pollepd p={e,event,0}; int r;
        health(); r=scif_poll(&p,1,100);
        if (r<0 && errno==EINTR) continue;
        if (r<0 || (p.revents&(SCIF_POLLHUP|SCIF_POLLERR|SCIF_POLLNVAL))) fail("SCIF peer disconnected",0);
        if (r>0 && (p.revents&event)) return;
    }
}
static void message(scif_epd_t e, frame *f, int send) {
    size_t offset=0;
    while (offset<sizeof *f) {
        int n; ready(e,send ? SCIF_POLLOUT : SCIF_POLLIN);
        n=send ? scif_send(e,(char *)f+offset,sizeof(*f)-offset,0) : scif_recv(e,(char *)f+offset,sizeof(*f)-offset,0);
        if (n<0 && (errno==EINTR || errno==EAGAIN)) continue;
        if (n<=0) fail("SCIF control message",0);
        offset+=(size_t)n;
    }
}
static void verify_lock(const char *token) {
    char s[80]; FILE *f=fopen("/tmp/knc-phase3-workload.lock/phi-chat-owner","r");
    if (!f || !fgets(s,sizeof s,f)) fail("card workload ownership missing",1);
    fclose(f); s[strcspn(s,"\r\n")]=0;
    if (strcmp(s,token)) fail("card workload ownership changed",1);
}
int main(int argc, char **argv) {
    uint64_t total,pos=0; unsigned long port; char *end;
    scif_epd_t e; struct scif_portID host;
    frame f; int fd; FILE *pid;
    if (argc!=7 || !hex32(argv[2]) || !hex32(argv[3]) || !valid_path(argv[4])) fail("invalid transfer arguments",1);
    errno=0; port=strtoul(argv[1],&end,10);
    if (errno || *end || port<1088 || port>65535) fail("invalid SCIF port",1);
    errno=0; total=strtoull(argv[5],&end,10);
    if (errno || *end || !total || total>INT64_MAX-4096 || argv[5][0]=='-') fail("invalid file size",1);
    {
        char expected[96]; snprintf(expected,sizeof expected,"/tmp/phi-chat-scif-%s",argv[2]);
        if (strcmp(argv[6],expected)) fail("invalid receiver directory",1);
    }
    verify_lock(argv[3]); part=argv[4];
    atexit(cleanup); signal(SIGTERM,stopped); signal(SIGINT,stopped); signal(SIGALRM,stopped); signal(SIGPIPE,SIG_IGN);
    snprintf(pid_path,sizeof pid_path,"%s/pid",argv[6]);
    pid=fopen(pid_path,"wx"); if (!pid) fail("receiver already exists",1);
    pid_owned=1;
    fprintf(pid,"%ld\n",(long)getpid()); if (fclose(pid)) fail("receiver identity",1);
    alarm(20); health();
    e=scif_open(); if (e==SCIF_OPEN_FAILED) fail("SCIF unavailable",0);
    host.node=0; host.port=(uint16_t)port;
    if (scif_connect(e,&host)<0) fail("SCIF host connection",0);
    memset(&f,0,sizeof f); f.tag=1; f.bytes=total; f.value=WINDOW; memcpy(f.nonce,argv[2],32); message(e,&f,1);
    message(e,&f,0);
    if (f.tag!=2 || f.position || f.bytes!=total || f.value!=WINDOW || memcmp(f.nonce,argv[2],32)) fail("SCIF host identity mismatch",1);
    verify_lock(argv[3]);
    fd=open(part,O_CREAT|O_EXCL|O_RDWR|O_NOFOLLOW,0600);
    if (fd<0) fail("cannot create owned partial file",1);
    created=1;
    if (ftruncate(fd,(off_t)((total+4095)&~4095ULL))) fail("cannot size partial file",1);
    while (pos<total) {
        size_t bytes=(size_t)((total-pos)<WINDOW ? total-pos : WINDOW);
        size_t length=(bytes+4095)&~4095UL;
        void *map; off_t offset;
        health(); verify_lock(argv[3]);
        map=mmap(NULL,length,PROT_READ|PROT_WRITE,MAP_SHARED,fd,(off_t)pos);
        if (map==MAP_FAILED) fail("cannot map file window",1);
        offset=scif_register(e,map,length,0,SCIF_PROT_READ|SCIF_PROT_WRITE,0);
        if (offset<0) fail("cannot register file window",0);
        memset(&f,0,sizeof f); f.tag=3; f.position=pos; f.bytes=bytes; f.value=(uint64_t)offset; message(e,&f,1);
        message(e,&f,0);
        if (f.tag!=4 || f.position!=pos || f.bytes!=bytes || f.value) fail("invalid DMA completion",1);
        /* Sender has completed SCIF_RMA_SYNC before this message. */
        if (scif_unregister(e,offset,length)) fail("cannot release DMA window",0);
        if (munmap(map,length)) fail("cannot release file mapping",1);
        pos+=bytes;
    }
    if (ftruncate(fd,(off_t)total) || fsync(fd) || close(fd)) fail("cannot finalize partial file",1);
    verify_lock(argv[3]);
    memset(&f,0,sizeof f); f.tag=5; f.position=total; f.bytes=total; message(e,&f,1);
    /* MPSS may discard queued control bytes on close. Keep the endpoint alive
     * until the sender reads DONE and closes it. No extra acknowledgement is
     * needed: the sender owns publication, and rejects any missing DONE. */
    for (;;) {
        struct scif_pollepd p={e,SCIF_POLLIN,0}; int r;
        health(); r=scif_poll(&p,1,100);
        if (r<0 && errno==EINTR) continue;
        if (r<0 || (p.revents&(SCIF_POLLHUP|SCIF_POLLERR|SCIF_POLLNVAL))) break;
        if (r>0 && (p.revents&SCIF_POLLIN)) {
            char extra; r=scif_recv(e,&extra,1,0);
            if (r<=0) break;
            fail("unexpected completion data",1);
        }
    }
    scif_close(e); success=1; alarm(0);
    puts("SCIF DMA receiver complete."); return 0;
}
