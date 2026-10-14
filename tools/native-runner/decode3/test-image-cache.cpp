#include "image-cache.h"
#include <cassert>
#include <cstring>
#include <cstdio>
#include <limits>
int main() {
    image_embedding_cache cache;
    float a[] = {1, -0.0f}, b[] = {2, 3}, c[] = {4, 5};
    assert(cache.put("a",a,2) == a && !cache.get("a") && !cache.bytes());
    cache.configure(16);
    auto copy = cache.put("a",a,2);
    assert(copy != a && !std::memcmp(copy,a,sizeof(a)));
    cache.put("b",b,2);
    assert(cache.get("a")); // refresh A, so B is evicted
    cache.put("c",c,2);
    assert(!cache.get("b") && cache.get("a") && cache.get("c") && cache.bytes()==16);
    assert(cache.put("oversized",a,std::numeric_limits<size_t>::max())==a && cache.bytes()==16);
    cache.configure(1024*1024);
    assert(!cache.get("a") && !cache.bytes());
    for (int i=0;i<257;++i) cache.put(std::to_string(i),a,2);
    assert(!cache.get("0") && cache.get("1") && cache.bytes()==256*8);
    cache.configure(0);
    assert(!cache.get("256") && !cache.bytes());
    puts("PASS image cache bit preservation, recency, eviction, disabled path, overflow and entry bound");
}
