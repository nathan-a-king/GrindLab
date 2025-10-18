fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios preflight

```sh
[bundle exec] fastlane ios preflight
```

Preflight (project settings) then verify App ID exists and is explicit

### ios sync_signing

```sh
[bundle exec] fastlane ios sync_signing
```

Sync signing via match (readonly true in CI)

### ios build

```sh
[bundle exec] fastlane ios build
```

Archive with gym

### ios upload

```sh
[bundle exec] fastlane ios upload
```

Upload IPA to TestFlight

### ios ci

```sh
[bundle exec] fastlane ios ci
```

CI pipeline: preflight → (match) → build → upload

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
