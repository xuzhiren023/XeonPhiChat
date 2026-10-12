modern == "modern-knc" && /^PHI_PROMPT_REJECTED [0-9]+$/ { count=$2; rejected=1; complete=1; next }
# Filter the pinned CLI's verbose stderr IN MEMORY. Never save prompt/token text.
# -f removes one trailing LF; the resulting quoted prompt occupies exactly the
# original file's NR records. Skip that block by length, not by its contents, so
# text imitating a diagnostic inside a user's prompt cannot forge the count.
BEGIN { skip = 0; expect_count = 0; complete = 0; bad = 0 }
complete { next }
modern == "modern-knc" && /^PHI_PROMPT_TOKENS [0-9]+$/ { count=$2; rejected=0; complete=1; next }
skip > 0 { skip--; next }
expect_count {
    if ($0 !~ /^main: number of tokens in prompt = [0-9]+$/) { bad = 1; complete = 1; next }
    count = $NF; rejected = 0; complete = 1; next
}
/^main: prompt: '/ {
    if (prompt_lines < 1) { bad = 1; complete = 1; next }
    skip = prompt_lines - 1; expect_count = 1; next
}
/^main: error: prompt is too long \([0-9]+ tokens, max [0-9]+\)$/ {
    value = $0; sub(/^main: error: prompt is too long \(/, "", value)
    sub(/ tokens, max [0-9]+\)$/, "", value)
    count = value; rejected = 1; complete = 1
}
END {
    if (!complete || bad || count !~ /^[0-9]+$/ || count < 1) {
        print "FAIL: native prompt count unavailable; inspect the worker exit and memory evidence" > "/dev/stderr"
        exit 1
    }
    printf "prompt_tokens=%d\nprompt_rejected=%d\n", count, rejected
}
