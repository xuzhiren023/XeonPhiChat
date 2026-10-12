using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
namespace PhiChat {
    // Only metadata is read. Tensor bytes are never scanned here.
    public static class GgufResources {
        static void Skip(BinaryReader r, ulong bytes) {
            if(bytes>(ulong)(r.BaseStream.Length-r.BaseStream.Position)) throw new InvalidDataException("Truncated GGUF metadata.");
            r.BaseStream.Seek((long)bytes,SeekOrigin.Current);
        }
        static string Text(BinaryReader r,bool keep) {
            ulong n=r.ReadUInt64();
            if(!keep){Skip(r,n);return null;}
            if(n>1048576) throw new InvalidDataException("Invalid GGUF metadata string.");
            byte[] b=r.ReadBytes((int)n);if(b.Length!=(int)n)throw new EndOfStreamException();
            return new UTF8Encoding(false,true).GetString(b);
        }
        static object Value(BinaryReader r,uint type,bool keep,int depth) {
            switch(type){
                case 0:return r.ReadByte();case 1:return r.ReadSByte();case 2:return r.ReadUInt16();case 3:return r.ReadInt16();
                case 4:return r.ReadUInt32();case 5:return r.ReadInt32();case 6:return r.ReadSingle();case 7:return r.ReadBoolean();
                case 8:return Text(r,keep);case 10:return r.ReadUInt64();case 11:return r.ReadInt64();case 12:return r.ReadDouble();
                case 9:
                    if(depth>2)throw new InvalidDataException("Nested GGUF arrays.");
                    uint t=r.ReadUInt32();ulong n=r.ReadUInt64();int[] sizes={1,1,2,2,4,4,4,1,0,0,8,8,8};
                    if(t>=sizes.Length)throw new InvalidDataException("Invalid GGUF array type.");
                    if(sizes[t]>0)Skip(r,checked(n*(ulong)sizes[t]));
                    else {if(n>(ulong)(r.BaseStream.Length-r.BaseStream.Position)/8)throw new InvalidDataException("Invalid GGUF array length.");for(ulong i=0;i<n;i++)Value(r,t,false,depth+1);}
                    return null;
                default:throw new InvalidDataException("Unsupported GGUF metadata type.");
            }
        }
        public static Dictionary<string,object> Read(string path){
            var result=new Dictionary<string,object>();
            using(var r=new BinaryReader(File.OpenRead(path))){
                if(r.ReadUInt32()!=0x46554747)throw new InvalidDataException("Not a GGUF model.");
                uint v=r.ReadUInt32();if(v!=2&&v!=3)throw new InvalidDataException("Unsupported GGUF version.");
                r.ReadUInt64();ulong n=r.ReadUInt64();if(n>(ulong)r.BaseStream.Length/12)throw new InvalidDataException("Invalid metadata count.");
                for(ulong i=0;i<n;i++){
                    string k=Text(r,true);bool keep=k=="general.architecture"||k.EndsWith(".context_length")||k.EndsWith(".block_count")||k.EndsWith(".embedding_length")||k.EndsWith(".attention.head_count")||k.EndsWith(".attention.head_count_kv")||k.EndsWith(".attention.key_length")||k.EndsWith(".attention.value_length");
                    object value=Value(r,r.ReadUInt32(),keep,0);if(keep&&value!=null)result.Add(k,value);
                }
            }return result;
        }
    }
}
