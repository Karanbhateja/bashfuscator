#!/bin/bash

# Generate random components
RAND_VAR() { 
    cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 12 | head -n 1
}

# Unique components per run
ENCRYPTION_KEY=$(openssl rand -hex 16)
VAR1=$(RAND_VAR)
VAR2=$(RAND_VAR)
VAR3=$(RAND_VAR)
JUNK_FUNC=$(RAND_VAR)
FAKE_VAR=$(RAND_VAR)
TRAP_NAME=$(RAND_VAR)

# Check dependencies
check_deps() {
    declare -A deps=(
        ["shc"]="sudo apt install shc"
        ["openssl"]="sudo apt install openssl"
        ["xxd"]="sudo apt install xxd"
        ["gzip"]="sudo apt install gzip"
        ["upx"]="sudo apt install upx"
    )

    for cmd in "${!deps[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            echo "ERROR: Missing $cmd - Install with: ${deps[$cmd]}"
            exit 1
        fi
    done
}

# Multi-layer obfuscation engine
obfuscate_payload() {
    local file="$1"
    
    # 9-layer transformation
    cat "$file" | \
    gzip -9 | \
    openssl enc -aes-256-cbc -salt -pass pass:"$ENCRYPTION_KEY" | \
    base64 | \
    rev | \
    xxd -p | \
    sed 's/../\\x&/g' | \
    base58 | \
    awk '{for(i=1;i<=NF;i++){printf "%04X", $i}}' | \
    split -b 64 -a 4 - --filter='echo -n "$FILE-$(cat)"' 
}

# Generate polymorphic script
generate_script() {
    local payload="$1"
    
    cat << EOF
#!/bin/bash

# Anti-debugging traps
trap 'echo -n; exit 123' SIGTRAP
trap '$(RAND_VAR)="\$($(RAND_VAR))"; kill -INT \$\$' INT

# Dynamic code reassembly
declare -A $VAR1
$VAR1[$(RAND_VAR)]="$(RAND_VAR)"
$VAR1[$VAR2]="$payload"
$VAR1[$(RAND_VAR)]="$(RAND_VAR)"

# Junk functions
$JUNK_FUNC() {
    for i in {1..100}; do
        echo "\$RANDOM" >/dev/null
        $FAKE_VAR=\$((\$RANDOM % 256))
    done
}

# Obfuscated decoder
$VAR3() {
    local _d="\${$VAR1[$VAR2]}"
    _d=\$(echo "\$_d" | tr '-' ' ' | xxd -r -p | rev | base58 -d | \\
        sed 's/\\\\x//g' | xxd -r -p | \\
        openssl enc -aes-256-cbc -d -pass pass:"$ENCRYPTION_KEY" | \\
        gzip -d)
    eval "\$_d"
}

# Anti-tampering check
if [[ \$(sha256sum "\$0" | cut -d' ' -f1) != "$(sha256sum "$1" | cut -d' ' -f1)" ]]; then
    echo "Integrity check failed!" >&2
    exit 1
fi

# Execute
$JUNK_FUNC
$VAR3

# Cleanup
unset $VAR1 $VAR2 $VAR3 $JUNK_FUNC $FAKE_VAR
EOF
}

# Main flow
check_deps

if [ $# -ne 1 ]; then
    echo "Usage: $0 <script.sh>"
    exit 1
fi

# Generate obfuscated payload
PAYLOAD=$(obfuscate_payload "$1")

# Create temp script
TMP_SCRIPT=$(mktemp)
generate_script "$PAYLOAD" > "$TMP_SCRIPT"

# Compilation options
echo -e "\nSelect compilation level:"
echo "1) Basic (SHC only)"
echo "2) Aggressive (SHC + UPX)"
read -p "Choice [1-2]: " comp_level

# Compile with SHC
shc -f "$TMP_SCRIPT" -o "${1%.*}.bin"

# Additional packing
if [ "$comp_level" == "2" ]; then
    upx --ultra-brute "${1%.*}.bin" >/dev/null
fi

# Cleanup
rm -f "$TMP_SCRIPT" "${TMP_SCRIPT}.x.c"

# Add anti-disassembly
echo '#!/bin/sh' | dd of="${1%.*}.bin" conv=notrunc bs=1 seek=0 2>/dev/null

echo -e "\nProtected binary created: ${1%.*}.bin"
