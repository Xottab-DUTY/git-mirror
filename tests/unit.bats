#!/usr/bin/env bats

load '../git-mirror.sh'

setup() {
    export TEST_DIR="${BATS_TMPDIR}/git_mirror_tests"
    mkdir -p "$TEST_DIR"

    ssh-keygen -t ed25519 -N "" -f "$TEST_DIR/id_free" >/dev/null

    ssh-keygen -t ed25519 -N "secret" -f "$TEST_DIR/id_locked" >/dev/null
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "generate_temp_file: temporary file created" {
    run generate_temp_file 10
    [ "$status" -eq 0 ]
    [ -f "$output" ]
    rm -f "$output"
}

@test "transform_target: no data makes no changes (HTTPS URL)" {
    run transform_target "https://github.com/user/repo.git"
    [ "${lines[0]}" == "https://github.com/user/repo.git" ]

    run transform_target "https://admin:secret123@github.com/user/repo.git"
    [[ "${lines[0]}" == "https://admin:secret123@github.com/user/repo.git" ]]

    run transform_target "https://secret123@github.com/user/repo.git"
    [[ "${lines[0]}" == "https://secret123@github.com/user/repo.git" ]]
}

@test "transform_target: no data makes no changes (SSH URL)" {
    run transform_target "git@github.com:user/repo.git"
    [ "${lines[0]}" == "git@github.com:user/repo.git" ]

    run transform_target "custom_user@github.com:user/repo.git"
    [ "${lines[0]}" == "custom_user@github.com:user/repo.git" ]
}

@test "transform_target: username and password appended correctly (HTTPS URL)" {
    run transform_target "https://github.com/user/repo.git" "admin" "secret123"
    [[ "${lines[0]}" == "https://admin:secret123@github.com/user/repo.git" ]]

    run transform_target "https://github.com/user/repo.git" "" "secret123"
    [[ "${lines[0]}" == "https://secret123@github.com/user/repo.git" ]]
}

@test "transform_target: username appended correctly (SSH URL)" {
    run transform_target "git@github.com:user/repo.git" "custom_user"
    [ "${lines[0]}" == "custom_user@github.com:user/repo.git" ]
}

@test "transform_target: SSH key file is correct" {
    local key_content=$(cat "$TEST_DIR/id_free")
    run transform_target "git@github.com:user/repo.git" "" "$key_content" ""

    [ "$status" -eq 0 ]
    local key_file="${lines[2]}"
    [ -f "$key_file" ]

    # Make sure the content is identical
    diff "$key_file" "$TEST_DIR/id_free"

    # Make sure the rights are correct (600)
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        [ "$(stat -c %a "$key_file")" == "600" ]
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        [ "$(stat -f %Lp "$key_file")" == "600" ]
    fi

    rm -f "$key_file"
}

@test "transform_target: private key is successfully unlocked with a correct passphrase" {
    local key_content=$(cat "$TEST_DIR/id_locked")

    run transform_target "git@github.com:user/repo.git" "" "$key_content" "secret"

    [ "$status" -eq 0 ]
    local key_file="${lines[2]}"

    ssh-keygen -y -f "$key_file" >/dev/null
    rm -f "$key_file"
}

@test "transform_target: fail on wrong passphrase" {
    local key_content=$(cat "$TEST_DIR/id_locked")
    run transform_target "git@github.com:user/repo.git" "" "$key_content" "wrong_pass"
    [ "$status" -eq 1 ]
}
