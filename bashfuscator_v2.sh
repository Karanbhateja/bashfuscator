#!/bin/bash

# Secure random name generator (Bash 4+ required)
RAND_VAR() {
    LC_ALL=C tr -dc 'a-zA-Z' </dev/urandom | fold -w 16 | head -n 1
}

# Generate unique components per run
ENCRYPTION_KEY=$(openssl rand -hex 32)
LAYER1_VAR=$(RAND_VAR)
LAYER2_VAR=$(RAND_VAR)
DECODE_FUNC=$(RAND_VAR)
JUNK_CALL=$(RAND_VAR)

# Validate input
if [ $# -ne 1 ]; then
    echo "Usage: $0 <script.sh>"
    exit 1
fi

# Generate multi-layer obfuscation
OBFUSCATED_CONTENT=$(
    gzip -9 -c "$1" | \
    openssl enc -aes-256-ctr -pass pass:"$ENCRYPTION_KEY" -md sha512 | \
    base64 -w 0 | \
    xxd -p -c 256 | \
    rev | \
    base58 | \
    sed 's/./&\n/g' | tac | paste -sd ''
)

# Build protected script
cat << EOF > temp_script.sh
#!/bin/bash

# Anti-version check
[[ \$- == *i* ]] && echo "Interactive shells disabled" >&2 && exit 1

# Random garbage
$(RAND_VAR)() { 
    for _ in {1..$((RANDOM%50+10))}; do 
        echo \$RANDOM > /dev/null
    done
}

# Encrypted payload (split)
${LAYER1_VAR}='$(echo "$OBFUSCATED_CONTENT" | fold -w 64)'
${LAYER2_VAR}="\$(tr -d '\n' <<< "\$${LAYER1_VAR}")"

# Dynamic decoder
${DECODE_FUNC}() {
    local _d="\$${LAYER2_VAR}"
    _d=\$(echo "\$_d" | \\
        rev | \\
        base58 -d | \\
        xxd -r -p | \\
        base64 -d | \\
        openssl enc -aes-256-ctr -d -pass pass:"$ENCRYPTION_KEY" | \\
        gzip -d)
    eval "\$_d"
}

# Anti-tampering
trap 'rm -- "\$0"; exit 255' SIGINT SIGTERM
${DECODE_FUNC}
EOF

# Compile with SHC using strict flags
shc -f temp_script.sh -o "$1.bin" -H \
    -e "31 Dec 2024" \
    -m "This binary has expired" \
    -r

# Strip debug symbols and pack
strip "$1.bin" 2>/dev/null
upx --ultra-brute "$1.bin" >/dev/null 2>&1

# Cleanup
rm -f temp_script.sh temp_script.sh.x.c

echo "Secure binary generated: $1.bin"
