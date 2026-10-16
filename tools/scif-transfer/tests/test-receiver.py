"""Runs only against the Linux host fixture linked to fake-scif.c, not a Phi.
Use an isolated compiler VM; root is needed for fixture /root path admission.
"""
import hashlib,os,pathlib,shutil,socket,struct,subprocess,sys,time,uuid
ROOT=pathlib.Path('/root/knc-phase3-run-fixture-'+uuid.uuid4().hex)
LOCK=pathlib.Path('/tmp/knc-phase3-workload.lock')
WINDOW=64*1024*1024
TOKEN=uuid.uuid4().hex
exe=pathlib.Path(sys.argv[1]).resolve()
assert 'fixture' in exe.name and not pathlib.Path('/dev/scif').exists()
assert not LOCK.exists()
ROOT.mkdir();LOCK.mkdir();(LOCK/'phi-chat-owner').write_text(TOKEN+'\n')

def frame(tag,pos=0,size=0,value=0,nonce=''):
    return struct.pack('<QQQQ32s',tag,pos,size,value,nonce.encode())
def recv(s):
    data=b''
    while len(data)<64:
        part=s.recv(64-len(data));assert part,'receiver disconnected';data+=part
    return struct.unpack('<QQQQ32s',data)
def case(mode,size=WINDOW+129):
    nonce=uuid.uuid4().hex; d=pathlib.Path('/tmp/phi-chat-scif-'+nonce);d.mkdir()
    output=ROOT/(mode+'-'+nonce+'.gguf.part')
    if mode=='existing':output.write_bytes(b'preserve existing file')
    listener=socket.socket();listener.bind(('127.0.0.1',0));listener.listen();listener.settimeout(8)
    p=subprocess.Popen([str(exe),str(listener.getsockname()[1]),nonce,TOKEN,str(output),str(size),str(d)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    connection=None
    try:
        p.stdin.write(b'health-ok\n');p.stdin.flush()
        connection,_=listener.accept();connection.settimeout(8)
        hello=recv(connection);assert hello==(1,0,size,WINDOW,nonce.encode())
        connection.sendall(frame(2,size=size,value=WINDOW,nonce=('0'*32 if mode=='nonce' else nonce)))
        expected=hashlib.sha256();pos=0
        if mode not in ('nonce','existing'):
            while pos<size:
                tag,at,n,offset,_=recv(connection)
                assert (tag,at,n,offset)==(3,pos,min(WINDOW,size-pos),4096)
                if mode=='disconnect':connection.close();connection=None;break
                if mode=='stop':p.stdin.close();break
                if mode=='wrong-position':connection.sendall(frame(4,pos=pos+1,size=n));break
                data=(bytes(range(256))*((n+255)//256))[:n]
                expected.update(data)
                padded=data+b'\0'*((-n)%64)
                connection.sendall(frame(99,size=len(padded))+padded)
                connection.sendall(frame(4,pos=pos,size=n));pos+=n
            if mode=='success':
                time.sleep(0.2)
                assert p.poll() is None, 'receiver closed before DONE was consumed'
                assert recv(connection)[:4]==(5,size,size,0)
                connection.close();connection=None
        code=p.wait(timeout=8);out,err=p.stdout.read(),p.stderr.read()
        if mode=='success':
            assert code==0,(code,err)
            assert output.stat().st_size==size
            assert hashlib.sha256(output.read_bytes()).digest()==expected.digest()
        elif mode=='existing':assert code==43 and output.read_bytes()==b'preserve existing file'
        else:assert code in (2,43) and not output.exists(),(mode,code,err)
        assert not (d/'pid').exists()
        print('PASS:',mode, 'bytes='+str(size))
    finally:
        if p.poll() is None:p.kill();p.wait()
        if connection:connection.close()
        listener.close();shutil.rmtree(d)
try:
    case('success',1)
    case('success',WINDOW+129)
    for mode in ('nonce','existing','disconnect','stop','wrong-position'):case(mode,4097)
finally:
    shutil.rmtree(ROOT);shutil.rmtree(LOCK)
print('PASS: offline receiver protocol/file lifecycle; no SCIF hardware used')
