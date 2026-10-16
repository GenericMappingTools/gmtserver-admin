# GMT Candidate Test Scratch Directory

This directory is a local scratch area for validating candidate server updates
without using a user's home directory.

Use it from the repository root with:

```sh
export GMT_USERDIR="$PWD/gmt_candidate_test"
```

The contents are ignored by git so the directory can safely collect GMT cache
files, downloads, and test outputs during candidate validation.