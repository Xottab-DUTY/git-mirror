#!/bin/bash

# Create temporary file with a random name
generate_temp_file()
{
    local length=${1:-32}
    local filename=""

    if command -v mktemp >/dev/null 2>&1; then
        for ((i=0; i<length; i++)); do
            filename+="X"
        done
        mktemp -t "git_mirror_$filename"
    else
        local chars=({a..z} {A..Z} {0..9})
        for ((i=0; i<length; i++)); do
            filename+="${chars[$RANDOM % ${#chars[@]}]}"
        done
        local tmp_file="/tmp/git_mirror_$filename"
        touch "$tmp_file"
        echo "$tmp_file"
    fi
}

transform_target()
{
    local raw_target="$1"
    local user="$2"
    local pass="$3"
    local final_url="$raw_target"
    local ssh_cmd=""
    local key_file=""

    if [[ "$raw_target" == git@* ]] || [[ "$raw_target" == ssh://* ]]; then
        if [ -n "$user" ] && [ "$user" != "git" ]; then
            if [[ "$raw_target" == git@* ]]; then
                final_url="${user}${raw_target#git}"
            elif [[ "$raw_target" == ssh://* ]]; then
                local path_no_proto="${raw_target#ssh://}"
                final_url="ssh://${user}@${path_no_proto#*@}"
            fi
        fi

        if [ -n "$pass" ]; then
            key_file=$(generate_temp_file)
            echo "$pass" > "$key_file"
            chmod 600 "$key_file"
            ssh_cmd="ssh -i $key_file -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes"
        fi
    elif [[ "$raw_target" == https://* ]]; then
        local url_path="${raw_target#https://}"
        local url_clean="${url_path#*@}"
        if [ -n "$user" ] && [ -n "$pass" ]; then
            final_url="https://${user}:${pass}@${url_clean}"
        elif [ -n "$pass" ]; then
            final_url="https://${pass}@${url_clean}"
        fi
    fi

    echo "$final_url" "$ssh_cmd" "$key_file"
}

TARGET="${1:-origin}"
USERNAME="$2"
PASSWORD="$3"
PUSH_ARGS="${4:- --mirror}"
SSH_KEY_FILE=""

echo "$GIT_SSH_COMMAND"
if [ -n "$USERNAME" ] || [ -n "$PASSWORD" ]; then
    {
        read -r TARGET
        read -r GIT_SSH_COMMAND
        read -r SSH_KEY_FILE
    } < <(transform_target "$TARGET" "$USERNAME" "$PASSWORD")

    [ -n "$GIT_SSH_COMMAND" ] && export GIT_SSH_COMMAND

    [ -n "$SSH_KEY_FILE" ] && trap 'rm -f "$SSH_KEY_FILE"' EXIT
fi

# Finita la comedia
export GIT_OPTIONAL_LOCKS=0
git push $PUSH_ARGS "$TARGET"
