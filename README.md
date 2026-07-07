# Causet CLI

The official command-line interface for Causet.

Causet CLI helps developers create, run, inspect, and ship Causet programs from their terminal. It is the primary developer entry point for working with the Causet runtime locally and in CI.

> Releases are currently published for the Causet CLI only.

## What is Causet?

Causet is a developer platform for building durable, event-driven applications. It gives teams a structured way to define workflows, events, projections, timelines, and runtime behavior without stitching together queues, cron jobs, workers, retries, and custom orchestration logic by hand.

## Features

* Initialize new Causet projects
* Run Causet programs locally
* Connect to a local Causet runtime
* Validate and inspect Causet definitions
* Support CI-friendly workflows
* Prepare projects for deployment
* Provide a stable developer interface for the Causet ecosystem

## Installation

Download the latest CLI release from the GitHub Releases page.

```bash
curl -fsSL https://raw.githubusercontent.com/causet-dev/causet-cli/main/install.sh | sh
```

After installation, verify the CLI is available:

```bash
causet --version
```

## Basic Usage

Create or initialize a Causet project:

```bash
causet init
```

Run a local Causet runtime:

```bash
causet dev
```

Validate your project:

```bash
causet check
```

Inspect available commands:

```bash
causet --help
```

## Releases

This repository publishes official GitHub Releases for the Causet CLI.

Each release may include platform-specific binaries for supported operating systems and architectures.

SDKs and other Causet packages are not released from this repository.

## Status

Causet CLI is under active development. Command names, runtime behavior, and project structure may change before the first stable release.

## Related Repositories

* `causet-sdks` — official SDKs for building Causet applications
* Causet runtime — runtime engine for executing Causet programs
* Causet compiler — compiler for validating and preparing Causet definitions

## License

License information will be added before the first public release.
