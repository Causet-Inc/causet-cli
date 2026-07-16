# Causet CLI

Official distribution repository for the Causet CLI.

This repository publishes prebuilt CLI and compiler binaries, the public installation script, and the local Docker Compose stack. The full CLI implementation is maintained in Causet’s private product monorepo and is not mirrored here.

## Install

```bash
curl -fsSL https://install.causet.io/install.sh | bash
causet version
causet doctor
```

Inspect the installer before running it:

```bash
curl -fsSL https://install.causet.io/install.sh
```

Pin a specific release by passing `CAUSET_VERSION` to the Bash process:

```bash
curl -fsSL https://install.causet.io/install.sh |
  env CAUSET_VERSION=vX.Y.Z bash
```

See the [Causet CLI releases](https://github.com/Causet-Inc/causet-cli/releases) for available versions.

## Run the wallet demo

Select the local environment and create the demo:

```bash
causet context use env local
causet new wallets my-wallets
cd my-wallets
```

`causet new` may offer to start the local runtime during interactive setup. Check its status and start it when necessary:

```bash
causet local status
causet local up
```

Start the wallet demo UI:

```bash
npm run dev --prefix app
```

Open:

```text
http://localhost:3850
```

The CLI does not open the browser automatically.

Create a wallet:

```bash
causet intent OPEN_WALLET \
  --stream wallet_stream \
  --entity wallet-alice \
  --fork sandbox \
  --payload '{"wallet_id":"wallet-alice","owner":"alice","currency":"USD"}'
```

Inspect its state and timeline:

```bash
causet inspect state \
  --entity wallet-alice \
  --stream wallet_stream \
  --fork sandbox

causet inspect timeline \
  --entity wallet-alice \
  --stream wallet_stream \
  --fork sandbox \
  --all
```

Stop the local runtime:

```bash
causet local down
```

Delete local runtime data:

```bash
causet local reset --yes
```

`causet local reset --yes` permanently removes the local Causet data managed by the development stack.

## What `causet new wallets` does

Unless `--no-install` is supplied, `causet new wallets my-wallets`:

* Creates `my-wallets/` from the public templates repository
* Requires the local CLI context
* Prompts to install or start the Docker stack when running interactively and the stack is unavailable
* Runs `npm install --prefix app`
* Creates the local platform and application records
* Compiles the Causet DSL
* Deploys the workflow to the `sandbox` fork
* Writes `.causet/causet.yaml`
* Updates `~/.causet/config.json`

It does **not** start the Node.js demo UI or open a browser.

To create only the project files:

```bash
causet new wallets my-wallets --no-install
```

## Repository contents

| Included                                     | Not included                        |
| -------------------------------------------- | ----------------------------------- |
| `install.sh` public installer                | Full CLI implementation source      |
| `docker-compose.yml` local development stack | Runtime service source              |
| GitHub Release CLI binaries                  | Compiler implementation source      |
| GitHub Release compiler binaries             | Managed Causet Cloud service source |
| `checksums.txt` release checksums            |                                     |
| `docs/CLI.md` command reference              |                                     |

## Command overview

### Project creation and development

```text
new
templates
build
dev
plan
deploy
```

### Local runtime

```text
local up
local down
local status
local logs
local reset
```

### Inspection

```text
inspect state
inspect entity
inspect timeline
inspect event
doctor
```

### Context

```text
context show
context use
```

### Managed Causet Cloud

```text
login
logout
dashboard
orgs
platforms
apps
```

Run the following command for the authoritative command tree:

```bash
causet --help
```

See [`docs/CLI.md`](./docs/CLI.md) for the complete command reference.

## Platform support

| Platform    | CLI       | Compiler                  | Local runtime                           |
| ----------- | --------- | ------------------------- | --------------------------------------- |
| macOS ARM64 | Native    | Native                    | Supported for development               |
| macOS AMD64 | Native    | Native                    | Supported for development               |
| Linux AMD64 | Native    | Native                    | Supported for development               |
| Linux ARM64 | Native    | AMD64 fallback or omitted | Development with documented limitations |
| Windows     | WSL2 only | WSL2 only                 | WSL2 development only                   |

A native `causet-compiler-linux-arm64` artifact is not currently published.

On Linux ARM64, either configure AMD64 execution through QEMU/binfmt or install the CLI without the compiler:

```bash
curl -fsSL https://install.causet.io/install.sh |
  env CAUSET_SKIP_COMPILER=1 bash
```

Compiler-dependent commands are unavailable when installation skips the compiler.

See [install.causet.io](https://install.causet.io/) for the current compatibility matrix and prerequisites.

## Maturity and production use

The primary CLI workflow is supported.

The bundled local Docker runtime and wallet demo are intended for development, evaluation, and testing. They are not supported as production deployment environments.

See [What runs today?](https://docs.causet.io/introduction/what-runs-today) for current availability, maturity, and production-support details.

## Related repositories

* [causet-templates](https://github.com/Causet-Inc/causet-templates) — demo and quickstart templates
* [causet-sdks](https://github.com/Causet-Inc/causet-sdks) — client SDKs
* [install.causet.io](https://install.causet.io/) — official installer and local-runtime instructions
* [`docs/CLI.md`](./docs/CLI.md) — full command reference

## Documentation

* [Product documentation](https://docs.causet.io/)
* [Local quickstart](https://docs.causet.io/getting-started/local-quickstart)
* [CLI releases](https://github.com/Causet-Inc/causet-cli/releases)
* [Installation guide](https://install.causet.io/)

## Security

Do not report security vulnerabilities through public GitHub issues.

Follow the private-reporting process in [`SECURITY.md`](./SECURITY.md).

## License

The contents of this repository and the prebuilt CLI and compiler binaries distributed through its GitHub Releases are licensed under the Apache License 2.0. See [`LICENSE`](./LICENSE).

Other Causet repositories and components may use different licenses.
