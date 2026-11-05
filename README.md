# tripl check

A GitHub action that checks the tracking calls in your code against your
[tripl](https://github.com/tripl-io/tripl) tracking plan. Under the hood it runs
`tripl check`:

- **Pull requests:** the check fails only on findings the pull request brings
  in. These are a new or edited call, or a constant or enum it changed. Legacy
  findings and plan edits never fail it.
- **Pushes and schedules:** there is no change to gate on. A committed
  baseline (`.tripl/check-baseline.json`) holds the findings you already know
  about, so the check fails only on findings it does not hold.
- **Code scanning:** findings are uploaded as alerts on the lines of the pull
  request.
- **An outage of tripl** passes with a warning, and nothing is checked.

```yaml
# .github/workflows/tracking-plan.yml
name: Tracking plan

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read
  security-events: write # to upload the findings to code scanning
  actions: read          # upload-sarif needs it on a private repository

jobs:
  tripl-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: tripl-io/tripl-check-action@vX.Y.Z
        with:
          base-url: https://tripl.example.com
          api-key: ${{ secrets.TRIPL_READ_ONLY_KEY }}
```

Pin a release: the action runs the tripl CLI of the same version. `vX.Y`
follows the patch releases of `X.Y`. To pin a commit instead, use
`tripl-io/tripl-check-action@<commit SHA> # vX.Y.Z`.

## Inputs

| Input | Default | What it does |
|-------|---------|--------------|
| `base-url` | `""` | The instance's `https://` address. Empty reads `TRIPL_BASE_URL`. |
| `api-key` | `""` | A read-only API key. Empty reads `TRIPL_API_KEY`. A pull request that has neither is skipped with a notice. That covers a fork's pull request and Dependabot's, since neither gets secrets. |
| `version` | the release you pinned | The tripl CLI release to run. |
| `project` | `""` | The tripl project. Empty reads it from the check config. |
| `check-config` | `""` | The check config, relative to the repository root. Empty finds the nearest `.tripl/check.yml`. |
| `directory` | `.` | Where to run, relative to the repository root. Use it for a repository with several apps. |
| `baseline` | `.tripl/check-baseline.json` | The committed baseline, used when the file exists. Empty never uses one. |
| `gate` | `true` | In a pull request or a merge queue, fail only on findings it brings in. |
| `strict` | `false` | Fail on warnings too. |
| `pass-on-outage` | `true` | Pass, with a warning, when tripl was unavailable (exit 4). |
| `sarif` | `true` | Upload the findings to code scanning. |
| `category` | `tripl-check[/<directory>]` | The code scanning category. Each app checked in its own step keeps its own. |
| `args` | `""` | More `tripl check` arguments, separated by spaces. |

The `exit-code` output is what `tripl check` exited with:

| Code | Meaning |
|------|---------|
| `0` | Passed |
| `1` | Findings |
| `2` | Configuration error |
| `4` | tripl was unavailable |

The output is empty when a pull request without a key was skipped.

With a merge queue, add `merge_group:` under `on:`; the action gates each group
on its base. The gate fetches the commits it needs into the shallow checkout.
On a private repository checked out with `persist-credentials: false` it cannot
fetch them, so check out with `fetch-depth: 0` there.

## More

- [Check tracking code in CI](https://github.com/tripl-io/tripl/blob/main/website/docs/how-to/check-tracking-in-ci.md):
  the whole setup, including the check config and the baseline, and GitLab
  (one `include`) and other CI systems.
- This repository mirrors `ci/github/action.yml` from each tripl CLI release
  (`cli-vX.Y.Z`). Report issues and send changes to
  [tripl-io/tripl](https://github.com/tripl-io/tripl).

## License

AGPL-3.0, as tripl.
