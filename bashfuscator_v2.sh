#!/bin/bash

# Secure random name generator
RAND_VAR() {
    LC_ALL=C tr -dc 'a-zA-Z' </dev/urandom | fold -w 16 | head -n 1
}

# Generate unique components
ENCRYPTION_KEY=$(openssl rand -hex 32)
LAYER1_VAR=$(RAND_VAR)
LAYER2_VAR=$(RAND_VAR)

# Validate input
[ $# -ne 1 ] && echo "Usage: $0 <script.sh>" && exit 1

# Obfuscation pipeline
OBFUSCATED_CONTENT=$(gzip -9 -c "$1" | openssl enc -aes-256-ctr -pbkdf2 -iter 100000 -pass pass:"$ENCRYPTION_KEY" -md sha512 | base64 -w 0 | xxd -p -c 256 | rev | base58 | sed 's/./&\n/g' | tac | paste -sd '')

# Generate temp script
cat << EOF > temp_script.sh
#!/bin/bash

# Anti-debugging
trap 'rm -f \$0; exit 255' SIGINT SIGTRAP

# Payload assembly
${LAYER1_VAR}='$(echo "$OBFUSCATED_CONTENT" | fold -w 64)'
${LAYER2_VAR}="\$(tr -d '\n' <<< "\$${LAYER1_VAR}")"

# Decoder
eval "\$(echo "\$${LAYER2_VAR}" | rev | base58 -d | xxd -r -p | base64 -d | openssl enc -aes-256-ctr -d -pbkdf2 -iter 100000 -pass pass:"$ENCRYPTION_KEY" -md sha512 | gzip -d)"
EOF

# Compile with fixed expiration
shc -f temp_script.sh -o "$1.bin" -H -e 12/31/2024 -m "Expired: Contact admin" -r

# Security bypass
sudo chmod +x "$1.bin"
sudo chattr +i "$1.bin"
sudo setcap cap_dac_override=eip "$1.bin"

# Cleanup
rm -f temp_script.sh temp_script.sh.x.c
[ -f "$1.bin" ] && echo "Success: $1.bin" || echo "Compilation failed"
