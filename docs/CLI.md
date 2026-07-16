# Causet CLI

Command-line interface for building, deploying, and operating Causet applications.

## Install (recommended)

```bash
curl -fsSL https://install.causet.io/install.sh | bash
causet version
causet doctor
```

Prebuilt binaries: [Causet-Inc/causet-cli releases](https://github.com/Causet-Inc/causet-cli/releases)

### Build from source (monorepo developers)

```bash
cd apps/causet-cli
go build -o causet .
```

Compiler commands require `causet-compiler` on `PATH`, next to `causet`, or via `CAUSET_COMPILER`.

## Wallet demo golden path

```bash
causet context use env local
causet new wallets my-wallets
cd my-wallets
causet local up          # skip if causet new already started the stack
npm run dev --prefix app # open http://localhost:3850 yourself
causet intent OPEN_WALLET --stream wallet_stream --entity wallet-alice --fork sandbox \
  --payload '{"wallet_id":"wallet-alice","owner":"alice","currency":"USD"}'
causet inspect state --entity wallet-alice --stream wallet_stream --fork sandbox
causet inspect timeline --entity wallet-alice --stream wallet_stream --fork sandbox --all
```

## What `causet new wallets` does

Default path (without `--no-install`):

1. Requires local CLI context
2. Ensures the local Docker stack is running (interactive prompt to start when down)
3. Copies the template into the project directory
4. Runs `npm install --prefix app`
5. Creates local platform + application via the local management API
6. Compiles DSL and deploys to `sandbox`
7. Writes `.causet/causet.yaml` and updates `~/.causet/config.json`

It does **not** start the demo UI or open a browser. Next step: `npm run dev --prefix app`.

## Command groups

```
Project creation:  new, templates
Local runtime:       local up, local down, local status, local logs, local reset
Build & deploy:      build, dev, plan, deploy
Context:             context show, context use
Inspection:          inspect state, inspect entity, inspect timeline, inspect event, doctor
Runtime ops:         intent, query, queries, inspect, watch
Cloud:               login, logout, dashboard, orgs, platforms, apps, usage
Advanced:            release, fork, webhook, secrets, recovery, forensics, projection
```

`inspect entity` shows the current entity snapshot. `inspect state` shows entity state, optionally at a timeline cursor.

Run `causet --help` or `causet help advanced` for the full tree.

## Local development runtime

When the active environment is **local** (`causet context use env local`):

- Management API: `http://localhost:8085`
- Query service: `http://localhost:8082`
- Realtime: `http://localhost:8081`
- Runtime API: `http://localhost:8080`
- No cloud login required (`SECURITY_LOCAL_OPEN=true` in local compose)

Hosted environments still require `causet login`.

## Maturity

The primary CLI workflow is supported. Local Docker runtime and demo templates have separate **development-only** support boundaries — not production-supported.

## Machine-readable docs

- Command manifest: [developer-flow.json](developer-flow.json)
- CLI reference: [docs/cli-reference.md](docs/cli-reference.md) (monorepo source; see [docs/CLI.md](https://github.com/Causet-Inc/causet-cli/blob/main/docs/CLI.md) on the public repo)

## Development

```bash
make test
make test-all
```

## License

Apache License 2.0 — see [LICENSE](../LICENSE).
