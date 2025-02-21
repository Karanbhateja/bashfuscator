#!/bin/bash

# Generate random variable names
VAR1=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 8 | head -n 1)
VAR2=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 8 | head -n 1)
VAR3=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 8 | head -n 1)

# Check input
if [ $# -ne 1 ]; then
    echo "Usage: $0 <input_script.sh>"
    exit 1
fi

INPUT_FILE="$1"
BASE_NAME=$(basename "$INPUT_FILE" .sh)
OBFUSCATED_FILE="obfuscated_${BASE_NAME}.sh"
BINARY_FILE="${BASE_NAME}.bin"

# Obfuscation function
obfuscate() {
    # Create layered obfuscation
    {
        echo '#!/bin/bash'
        echo "# Garbage comment: $RANDOM$RANDOM$RANDOM"
        echo "declare -A $VAR1"
        echo "$VAR1[$VAR2]=\"$(gzip -c $1 | base64 | tr -d '\n' | xxd -p)\""
        echo "for $VAR3 in {1..3}; do let $VAR3+=1; done"
        echo "IFS='-' read -ra ${VAR1}_parts <<< \"\${$VAR1[$VAR2]}\""
        echo "eval \"\$(echo -n \${${VAR1}_parts[@]} | xxd -r -p | base64 -d | gunzip)\""
        echo "echo \"Cleanup...\" >/dev/null"
        echo "unset $VAR1 $VAR2 $VAR3"
    } > "$OBFUSCATED_FILE"

    chmod +x "$OBFUSCATED_FILE"
}

# Compilation function
compile() {
    if ! command -v shc &> /dev/null; then
        echo -e "\nERROR: shc (Shell Script Compiler) not found!"
        echo "Install with:"
        echo "  Ubuntu/Debian: sudo apt install shc"
        echo "  RHEL/CentOS:   sudo yum install shc"
        echo "  From source:   https://github.com/neurobin/shc"
        exit 1
    fi

    echo -e "\nCompiling $OBFUSCATED_FILE to binary..."
    shc -f "$OBFUSCATED_FILE" -o "$BINARY_FILE"
    
    # Cleanup shc artifacts
    rm -f "$OBFUSCATED_FILE.x.c"
    
    if [ -f "$BINARY_FILE" ]; then
        echo "Success! Compiled binary: $(realpath $BINARY_FILE)"
    else
        echo "Compilation failed!"
        exit 1
    fi
}

# Main execution
obfuscate "$INPUT_FILE"
echo -e "\nObfuscated script created: $(realpath $OBFUSCATED_FILE)"

# Prompt for compilation
read -p "Do you want to compile to binary? [y/N] " response
if [[ "$response" =~ ^[Yy]$ ]]; then
    compile
    
    # Prompt to remove obfuscated script
    read -p "Remove obfuscated script? [y/N] " remove_response
    if [[ "$remove_response" =~ ^[Yy]$ ]]; then
        rm -f "$OBFUSCATED_FILE"
        echo "Removed obfuscated script"
    fi
else
    echo "Skipping compilation"
fi
