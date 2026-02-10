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
    local username="$2"
    local password="$3"
    local passphrase="$4"
    local known_hosts="$5"
    local final_url="$raw_target"
    local ssh_cmd=""
    local key_file=""
    local hosts_file=""

    if [[ "$raw_target" == git@* ]] || [[ "$raw_target" == ssh://* ]]; then
        if [ -n "$username" ] && [ "$username" != "git" ]; then
            if [[ "$raw_target" == git@* ]]; then
                final_url="${username}${raw_target#git}"
            elif [[ "$raw_target" == ssh://* ]]; then
                local path_no_proto="${raw_target#ssh://}"
                final_url="ssh://${username}@${path_no_proto#*@}"
            fi
        fi

        if [ -n "$password" ]; then
            key_file=$(generate_temp_file)
            echo "$password" > "$key_file"
            chmod 600 "$key_file"

            if [ -n "$passphrase" ]; then
                if ! ssh-keygen -p -P "$passphrase" -N "" -f "$key_file" >/dev/null; then
                    rm -f "$key_file"
                    exit 1
                fi
            fi

            if [ -n "$known_hosts" ]; then
                hosts_file=$(generate_temp_file)
                echo "$known_hosts" > "$hosts_file"
                chmod 600 "$hosts_file"
                ssh_cmd="ssh -i $key_file -o UserKnownHostsFile=$hosts_file -o IdentitiesOnly=yes"
            else
                ssh_cmd="ssh -i $key_file -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes"
            fi
        fi
    elif [[ "$raw_target" == https://* ]]; then
        local url_path="${raw_target#https://}"
        local url_clean="${url_path#*@}"
        if [ -n "$username" ] && [ -n "$password" ]; then
            final_url="https://${username}:${password}@${url_clean}"
        elif [ -n "$password" ]; then
            final_url="https://${password}@${url_clean}"
        fi
    fi

    printf "%s\n" "$final_url" "$ssh_cmd" "$key_file" "$hosts_file"
}

main()
{
    local target="$1"
    local username="$2"
    local password="$3"
    local passphrase="$4"
    local push_args="$5"
    local refspec="$6"
    local known_hosts="$7"
    local ssh_key_file
    local ssh_hosts_file

    echo "Pushing to target: $target"
    echo "   with arguments: $push_args"

    if [ -n "$username" ] || [ -n "$password" ]; then
        {
            read -r target
            read -r GIT_SSH_COMMAND
            read -r ssh_key_file
            read -r ssh_hosts_file
        } < <(transform_target "$target" "$username" "$password" "$passphrase" "$known_hosts")

        [ -n "$GIT_SSH_COMMAND" ] && export GIT_SSH_COMMAND

        [ -n "$ssh_key_file" ] || [ -n "$ssh_hosts_file" ] && trap 'rm -f "$ssh_key_file" "$ssh_hosts_file"' EXIT
    fi

    # --no-optional-locks won't work with outdated git
    # so using env variable is less hustle
    export GIT_OPTIONAL_LOCKS=0

    # Finita la comedia
    git push $push_args "$target" $refspec
}

# If someone included the script, we're not going to immediately execute our logic
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    TARGET="${1:-origin}"
    USERNAME="$2"
    PASSWORD="$3"
    PASSPHRASE="$4"
    PUSH_ARGS="${5:- --mirror}"
    REFSPEC="$6"
    KNOWN_HOSTS="$7"
    echo "Supplied push target: $1"
    echo "      with arguments: $5"
    main "$TARGET" "$USERNAME" "$PASSWORD" "$PASSPHRASE" "$PUSH_ARGS" "$REFSPEC" "$KNOWN_HOSTS"
fi
