# Validating a remote dataset update on the candidate server

Notes distilled from `README.md`, `MAINTENANCE.md`, the `Makefile` help text and `scripts/`
(upstream gmtserver-admin as of Oct 2026). "candidate" and "oceania" are the same server;
they are two sub-directories (`candidate/server` and `data/server`) behind different URLs.

## 1. Build the dataset in staging
- `scripts/srv_downsampler.sh <dataset> -n` (dry run), then without `-n`
- `scripts/srv_tiler.sh <dataset> -n`, then without `-n` (also writes `<dataset>_server.txt`)
- For updates to existing data, `make <dataset>` (e.g. `make earth-faa`) runs both steps

## 2. Place on the candidate server
- `make place-<dataset>` (e.g. `make place-earth-faa`) -> `scripts/place_candidate.sh <dataset>`
- Deletes the old copy of that dataset on candidate, scp's the staged copy, sets permissions
- Does NOT touch public (oceania) data

## 3. Rebuild the candidate index
- `make candidate-info` -> `scripts/srv_candidate_server.sh` rebuilds `gmt_data_server.txt`
  from the dataset snippets found on candidate (place_candidate.sh does not do this itself)
- `scripts/srv_staging_vs_candidate.sh <dir>` checks all staged files arrived

## 4. Test with GMT against candidate
Use a clean GMT user dir so cached copies cannot hide problems. The standard
entry points are:

- `scripts/validate_earth_gebco_candidate.sh` to verify that the candidate
  GEBCO datasets are reachable and that GMT can read and cut them.
- `scripts/compare_earth_gebco_candidate.sh` to compare the candidate outputs
  against the operational `oceania` copies.

Both scripts write reusable artifacts under `gmt_candidate_test/earth_gebco/`.
The comparison script reuses the functional-validation artifacts when they are
already present, so a typical flow is validation first, comparison second.

Check several resolutions and both registrations, including tiled resolutions.
`make test-release` pushes candidate to the separate "guru test" server if wanted.

## 5. Release to public (oceania)
- `make server-release` -> `scripts/server-release.sh` (prompts; give a dataset name or blank for all)
- rsync candidate/server -> data/server (no --delete), old gmt_data_server.txt saved as `.prev`,
  candidate's gmt_data_server.txt copied over the public one
- CAUTION: the candidate index replaces the public index. Make sure it lists every dataset
  that should be public, not only the one you updated.

## 6. Clean up
- `make candidate-delete`

## Gravity datasets that read from topex.ucsd.edu/pub/global_grav_1min/
`earth_faa`, `earth_faaerror`, `earth_vgg`, `earth_edefl`, `earth_ndefl`
(each sets `SRC_FILE` on line 13; currently V33.1, V34.1 exists upstream).

## EC2 / S3 adaptation (TO DO - not yet implemented here)
The upstream scripts assume ssh/scp/rsync to SOEST hosts (`candidate.generic-mapping-tools.org`).
For the EarthScope AWS setup, `place_candidate.sh`, `server-release.sh` and
`srv_candidate_server.sh` need S3 equivalents (e.g. `aws s3 sync` between candidate and
release prefixes/buckets, then rebuild `gmt_data_server.txt`). Decide first which
bucket/prefix plays "candidate" and which plays "public", and how CloudFront serves each.
