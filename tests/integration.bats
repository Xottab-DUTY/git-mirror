#!/usr/bin/env bats

load '../git-mirror.sh'

TEST_TARGET="https://github.com/$GITHUB_REPOSITORY.git"

@test "main: git push --mirror $TEST_TARGET (HTTPS)" {
    run main "$TEST_TARGET" "" "$GITHUB_TOKEN" "" "--mirror --dry-run"
    echo "Git output: $output"
    [ "$status" -eq 0 ]
}

@test "main: git push --tags --prune --force $TEST_TARGET refs/remotes/origin/*:refs/heads/* (HTTPS)" {
    run main "$TEST_TARGET" "" "$GITHUB_TOKEN" "" "--tags --prune --force --dry-run" "refs/remotes/origin/*:refs/heads/*"
    echo "Git output: $output"
    [ "$status" -eq 0 ]
}
