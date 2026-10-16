/* Offline receiver fixture ONLY. TCP emulates control messages and a DMA write.
 * Never linked into either release helper. No driver or card calls. */
#include <scif.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
static void *mapping;
static size_t mapping_length;
scif_epd_t scif_open(void) { return socket(AF_INET,SOCK_STREAM,0); }
int scif_close(scif_epd_t e) { return close(e); }
int scif_connect(scif_epd_t e,struct scif_portID *p) {
    struct sockaddr_in a;
    memset(&a,0,sizeof a); a.sin_family=AF_INET;a.sin_port=htons(p->port);a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
    return connect(e,(struct sockaddr *)&a,sizeof a);
}
int scif_send(scif_epd_t e,void *p,int n,int flags) { (void)flags;return send(e,p,n,0); }
int scif_recv(scif_epd_t e,void *p,int n,int flags) {
    uint64_t f[8]; int r; (void)flags;
    r=recv(e,f,sizeof f,MSG_PEEK|MSG_WAITALL);
    if (r==sizeof f && f[0]==99) {
        if (!mapping || f[2]>mapping_length) {errno=EINVAL;return -1;}
        if (recv(e,f,sizeof f,MSG_WAITALL)!=sizeof f) return -1;
        if (recv(e,mapping,f[2],MSG_WAITALL)!=(ssize_t)f[2]) return -1;
    }
    return recv(e,p,n,0);
}
int scif_poll(struct scif_pollepd *p,unsigned int n,long timeout) {return poll((struct pollfd *)p,n,(int)timeout);}
off_t scif_register(scif_epd_t e,void *p,size_t n,off_t off,int prot,int flags) {
    (void)e;(void)off;(void)prot;(void)flags;mapping=p;mapping_length=n;return 4096;
}
int scif_unregister(scif_epd_t e,off_t off,size_t n) {(void)e;(void)off;(void)n;mapping=0;mapping_length=0;return 0;}
