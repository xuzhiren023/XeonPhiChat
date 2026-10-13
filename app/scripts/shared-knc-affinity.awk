# Input: allowed<TAB>CPU-list, followed by cpu<TAB>ID<TAB>sibling-list.
# Output: spread ordering across the usable cores, reserving CPU 0's entire core.
function reject() { bad=1; exit 1 }
function expand(list, out,  n,a,i,b,j,k,count) {
    if (list !~ /^[0-9,-]+$/) reject()
    n=split(list,a,","); count=0
    for(i=1;i<=n;i++) {
        k=split(a[i],b,"-")
        if(k>2 || b[1]<0 || b[1]>255 || (k==2 && (b[2]<b[1] || b[2]>255))) reject()
        for(j=b[1];j<=(k==2?b[2]:b[1]);j++) out[++count]=j
    }
    return count
}
$1=="allowed" {
    if (seen_allowed++) reject()
    n=expand($2,ids); if(n!=cores*4) reject()
    for(i=1;i<=n;i++) { if(allowed[ids[i]]++) reject() }
    next
}
$1=="cpu" {
    if($2 !~ /^[0-9]+$/ || !allowed[$2] || seen[$2]++) reject()
    n=expand($3,ids); if(n!=4) reject()
    # Normalize sibling order to ascending CPU IDs.
    for(i=1;i<=n;i++) for(j=i+1;j<=n;j++) if(ids[i]>ids[j]) { t=ids[i];ids[i]=ids[j];ids[j]=t }
    key=ids[1]; member=0
    for(i=1;i<=4;i++) {
        if(!allowed[ids[i]] || (i>1 && ids[i]==ids[i-1])) reject()
        if(ids[i]==$2) member=1
        if((key SUBSEP i) in group && group[key,i]!=ids[i]) reject()
        group[key,i]=ids[i]
        if(ids[i] in owner && owner[ids[i]]!=key) reject()
        owner[ids[i]]=key
    }
    if(!member) reject()
    keys[key]=1; rows++; next
}
{ reject() }
END {
    if(bad || rows!=cores*4 || seen_allowed!=1 || (cores!=57 && cores!=61) || workers<cores-1 || workers>4*(cores-1) || workers%(cores-1)!=0) exit 1
    groups=0; for(key in keys) groups++
    if(groups!=cores || !(0 in owner) || owner[0]!=0) exit 1
    count=0
    for(s=1;s<=workers/(cores-1);s++) for(key=1;key<=255;key++) if(key in keys) {
        printf "%s%d",count?" ":"",group[key,s]; count++
    }
    if(count!=workers) exit 1
    printf "\n"
}
