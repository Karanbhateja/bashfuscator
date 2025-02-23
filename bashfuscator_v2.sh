#!/bin/bash

# Safer random name generator (letters only)
RAND_VAR() { 
    cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 12 | head -n 1 | grep -E '^[a-z]' || RAND_VAR
}

# Generate compatible components
ENCRYPTION_KEY=$(openssl rand -hex 16)
VAR1=$(RAND_VAR)
VAR2=$(RAND_VAR)
VAR3=$(RAND_VAR)

# Add Bash version check
{
    echo '#!/usr/bin/env bash'
    echo '(( BASH_VERSINFO[0] < 4 )) && echo "Requires Bash 4+" && exit 1'
    
    # Modified array declaration
    echo "declare -A ${VAR1}=()"
    echo "${VAR1}[${VAR2}]=\"$(gzip -c $1 | openssl enc -base64 -A)\""
    
    # Simplified decoder
    echo "eval \"\$(echo -n \${${VAR1}[${VAR2}]} | base64 -d | openssl enc -d -base64 | gunzip)\""
    
} > obfuscated_script.sh

# Test before compilation
if ! bash -n obfuscated_script.sh; then
    echo "Syntax error in generated script!"
    exit 1
fi

# Compile with SHC
shc -f obfuscated_script.sh -o output.bin

# Verify binary
if [ -f output.bin ]; then
    echo "Success! Test with: ./output.bin"
else
    echo "Compilation failed!"
fi
