#include "prefix-cache.h"
#include <cassert>
#include <cstdio>

static prefix_atom text(int t) { prefix_atom a; a.token=t; return a; }
static prefix_atom image(const char *key,int n) { prefix_atom a; a.image=key; a.positions=n; a.tokens=n; return a; }
int main() {
    const std::vector<prefix_atom> old={text(1),image("blue:0",169),text(2),text(3)};
    auto next=old; next.push_back(text(4));
    auto d=choose_prefix(old,next,true,false,true,0,171);
    assert(!d.reset && d.positions==172 && d.tokens==172 && d.images==1);
    d=choose_prefix(old,next,true,true,true,171,171);
    assert(!d.reset && d.atoms==old.size());
    next.back()=text(5); next[3]=text(9);
    d=choose_prefix(old,next,true,false,true,0,171);
    assert(!d.reset && d.positions==171 && d.atoms==3);
    assert(choose_prefix(old,next,true,true,true,171,171).reset);
    next=old; next[1]=image("red:0",169);
    d=choose_prefix(old,next,true,false,true,0,171);
    assert(d.atoms==1 && d.images==0 && d.positions==1);
    next=old; next[1]=image("blue:1",169);
    assert(choose_prefix(old,next,true,false,true,0,171).atoms==1);
    next=old; next[1]=image("blue:0",170);
    assert(choose_prefix(old,next,true,false,true,0,171).atoms==1);
    next={text(1),image("blue:0",169)};
    d=choose_prefix(old,next,true,false,true,0,171);
    assert(d.atoms==1); // Whole trailing image must be recomputed for logits.
    next=old;
    assert(choose_prefix(old,next,true,false,true,0,171).atoms==3);
    assert(choose_prefix(old,next,false,false,true,0,171).reset);
    assert(choose_prefix(old,next,true,false,false,0,171).reset);
    assert(choose_prefix(old,next,true,false,true,1,171).reset);
    assert(choose_prefix(old,next,true,false,true,0,170).reset);
    assert(choose_prefix({},next,true,false,true,-1,-1).reset);
    assert(choose_prefix(old,{},true,false,true,0,171).reset);
    size_t checks=14;
    for (int n=1;n<128;++n) {
        std::vector<prefix_atom> a; for(int i=0;i<n;++i)a.push_back(text(i));
        for(int edit=0;edit<n;++edit) {
            auto b=a; b[edit]=text(-1); b.push_back(text(n));
            auto p=choose_prefix(a,b,true,false,true,0,n-1);
            assert(p.atoms==size_t(edit) && p.positions==edit && p.reset==(edit==0));
            assert(choose_prefix(a,b,true,true,true,n-1,n-1).reset); checks+=2;
        }
    }
    std::printf("PASS %zu prefix/history policy checks; native state execution is separate\n",checks);
}
