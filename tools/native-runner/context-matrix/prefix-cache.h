// SPDX-License-Identifier: MIT
#pragma once
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

struct prefix_atom {
    int32_t token = 0;
    int32_t positions = 1;
    size_t tokens = 1;
    std::string image;
    bool operator==(const prefix_atom & b) const {
        return token == b.token && positions == b.positions && tokens == b.tokens && image == b.image;
    }
};
struct prefix_decision {
    size_t atoms = 0, tokens = 0, images = 0;
    int32_t positions = 0;
    bool reset = true;
    const char * reason = "cold";
};
inline int32_t prefix_positions(const std::vector<prefix_atom> & atoms) {
    int64_t n=0;
    for (const auto & a : atoms) n+=a.positions;
    return n <= INT32_MAX ? int32_t(n) : -1;
}
// Image chunks are indivisible: a partial non-causal image is never reused.
inline prefix_decision choose_prefix(const std::vector<prefix_atom> & old,
                                     const std::vector<prefix_atom> & next,
                                     bool enabled, bool recurrent, bool simple_positions,
                                     int32_t memory_min, int32_t memory_max) {
    prefix_decision d;
    if (!enabled) { d.reason="disabled"; return d; }
    if (!simple_positions) { d.reason="complex_positions"; return d; }
    if (old.empty() || next.empty()) return d;
    const int32_t end=prefix_positions(old);
    if (end <= 0 || memory_max != end-1 || (!recurrent && memory_min != 0)) {
        d.reason="memory_mismatch"; return d;
    }
    while (d.atoms < old.size() && d.atoms < next.size() && old[d.atoms] == next[d.atoms]) ++d.atoms;
    // Always evaluate a last prompt atom to obtain fresh next-token logits.
    if (d.atoms == next.size()) --d.atoms;
    if (recurrent && d.atoms != old.size()) {
        d.atoms=0; d.reason="recurrent_history_change"; return d;
    }
    if (!d.atoms) { d.reason="history_change"; return d; }
    for (size_t i=0; i<d.atoms; ++i) {
        d.positions+=next[i].positions; d.tokens+=next[i].tokens;
        d.images+=!next[i].image.empty();
    }
    d.reset=false; d.reason=d.atoms == old.size() ? "append" : "trimmed_suffix";
    return d;
}
