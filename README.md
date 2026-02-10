# Git Mirror

This action allows you to mirror your repository to another repository.

- Works on any runner: `windows-latest`, `ubuntu-latest`, `ubuntu-slim`, `macos-latest`.
- It's just a simple, single Bash script that doesn't use Docker or anything, which is extremely usable for `ubuntu-slim` runners.
- Doesn't manipulate your repository's remotes:
  - Pushes to the target repository directly instead of adding it to remotes.
- Doesn't use standard filenames like `~/.ssh/id_rsa`, `~/.ssh/known_hosts`, etc. which can be used by you:
  - Creates temporary files instead and removes them when the work is done.
- Not compatible with POSIX Shell as it depends on Bash features. File an issue if you need it in your use case.
- Unlicensed, so you can take the underlying script and do whatever you want with it.

## Usage

### Simple

By default, all refs (all commits in all branches, tags, remotes and more) are being pushed, check the [advanced usage example](#push-only-the-branches-and-tags) below if you want to restrict that.

Protocol is determined automatically, you don't need to explicitly specify if it's HTTPS or SSH, and only the password is just enough.

To push from your repository to `https://github.com/user/repo.git`, use this setup:

#### HTTPS

```yml
- uses: actions/checkout@v6
    with:
    fetch-depth: 0 # this is required for correct mirroring

- uses: Xottab-DUTY/git-mirror@v1.0.0
  with:
    target: https://github.com/user/repo.git
    password: ${{ secrets.MY_TOKEN }}
```

#### SSH

```yml
- uses: actions/checkout@v6
    with:
    fetch-depth: 0 # this is required for correct mirroring

- uses: Xottab-DUTY/git-mirror@v1.0.0
  with:
    target: git@github.com:org/repo.git
    password: ${{ secrets.SSH_PRIVATE_KEY }}
```

### Advanced

#### Push only the branches and tags

By default, this action uses `git push --mirror` command, but `--mirror` argument pushes everything you have in `.git/refs` (i.e. notes, remotes, etc.). You can limit it by using this setup:

```yml
- uses: actions/checkout@v6
    with:
    fetch-depth: 0 # this is required for correct mirroring

- uses: Xottab-DUTY/git-mirror@v1.0.0
  with:
    target: git@github.com:org/repo.git
    password: ${{ secrets.SSH_PRIVATE_KEY }}
    #  --mirror implies these flags, but it's not restricted to that.
    push_args: "--tags --prune --force"
    # This refspec prevents pushing refs that were e.g. created locally on the runner during the workflow
    refspec: "refs/remotes/origin/*:refs/heads/*"
```

#### Reference

```yml
- uses: Xottab-DUTY/git-mirror@v1.0.0
  with:
    # HTTPS or SSH URL to the target remote repository to mirror everything to.
    # Can contain the username and/or password.
    # Must be specified.
    target:

    # Username for the target repository.
    # Replaces the username specified in the URL.
    # Default: unspecified
    username:

    # An access token, HTTPS password or SSH private key for the target repository.
    # Replaces the password specified in the URL.
    # Default: unspecified
    password:

    # The passphrase for the supplied private SSH key.
    # Default: unspecified
    passphrase:

    # Known hosts to be passed to ssh.
    # Default: unspecified
    known_hosts:

    # The push arguments to be used for mirroring.
    # Default: --mirror
    push_args: "--mirror"

    # Custom refspec to use for mirroring.
    # Default: unspecified
    refspec:

    # Convenience option to test things before doing real pushes.
    # Adds --dry-run to the push_args.
    # Default: false
    dry: false
```
