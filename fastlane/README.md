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

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload a new build to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Increment build number, build and upload the latest version to App Store Connect (all metadata, no screenshots, no review submission)

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload screenshots and metadata only (no binary, no review submission)

### ios incrementbuildnumber

```sh
[bundle exec] fastlane ios incrementbuildnumber
```

Increment build number

### ios setversion

```sh
[bundle exec] fastlane ios setversion
```

Set version

### ios test

```sh
[bundle exec] fastlane ios test
```

Run tests

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
