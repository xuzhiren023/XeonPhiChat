// SPDX-License-Identifier: MIT
#pragma once
#include <algorithm>
#include <cstddef>
#include <list>
#include <string>
#include <vector>

// One resident model/projector/policy owns one cache. Returned pointers remain
// valid only until another put/clear; embeddings contain no decoder KV state.
class image_embedding_cache {
    struct entry { std::string key; std::vector<float> data; };
    std::list<entry> entries;
    size_t limit = 0, used = 0;
public:
    void configure(size_t bytes) { entries.clear(); used = 0; limit = bytes; }
    size_t bytes() const { return used; }
    float * get(const std::string & key) {
        auto found = std::find_if(entries.begin(), entries.end(), [&](const entry & e) { return e.key == key; });
        if (found == entries.end()) { return nullptr; }
        entries.splice(entries.begin(), entries, found);
        return entries.front().data.data();
    }
    float * put(const std::string & key, float * data, size_t count) {
        if (!count || count > limit / sizeof(float)) { return data; }
        if (float * existing = get(key)) { return existing; }
        const size_t bytes = count * sizeof(float);
        while (!entries.empty() && (used > limit - bytes || entries.size() >= 256)) {
            used -= entries.back().data.size() * sizeof(float);
            entries.pop_back();
        }
        entries.push_front({key, std::vector<float>(data, data + count)});
        used += bytes;
        return entries.front().data.data();
    }
};
