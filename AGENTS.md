# AGENTS.md

## Project overview

This repository builds and runs a TYPO3 installation with
Kitodo.Presentation using Docker Compose. It can also set up
Kitodo.Presentation together with the DFG-Viewer. The main application is
assembled by `Dockerfile` and initialized by `docker-entrypoint.sh`.

Repository branches target different Kitodo.Presentation and DFG-Viewer
versions. Check the active branch before making compatibility-sensitive
changes. Examples include `presentation-v3.x`, `presentation-v4.x`,
`presentation-v6.x`, and `presentation-v7.x`; DFG-Viewer variants use their
own corresponding branches.

## Repository layout

- `docker-compose.yml`: Defines TYPO3, MariaDB, and the optional Solr and
  phpMyAdmin services.
- `Dockerfile`: Builds the TYPO3/Kitodo.Presentation image.
- `docker-entrypoint.sh`: Performs the one-time TYPO3 and extension setup.
- `data/`: Contains site configuration, SQL data, and files copied into the
  image.
- `data/scripts/`: Contains optional post-installation scripts. Enabled scripts
  ending in `.sh` run as root.
- `packages/`: Contains local Composer-managed TYPO3 extensions and site
  packages.
- `volumes/`: Contains host-mounted runtime data. Do not commit generated
  runtime files.

## Working guidelines

- Keep changes compatible with TYPO3 v13 and PHP 8.2.
- Use Composer for TYPO3 extension dependencies. Put local extensions in
  `packages/` and register them through the existing Composer path repository.
- Treat `docker-entrypoint.sh` as first-run setup: its guarded initialization
  runs only when `/initFinished` does not exist inside the container.
- Preserve optional Docker Compose profiles for Solr and phpMyAdmin.
- Do not add secrets or credentials from `.env` to tracked files.
- Do not remove containers, images, or volumes unless the user explicitly asks.
  In particular, avoid `docker compose down --volumes` because it can remove
  database data.
- Preserve unrelated working-tree changes.

## Validation

Run checks appropriate to the changed files:

```sh
bash -n docker-entrypoint.sh docker-entrypoint-aux.sh
docker compose config
git diff --check
```

For image-related changes, also run:

```sh
docker compose build main
```

Do not start the full stack merely to validate documentation or static
configuration changes.

## Conventions

1. Commits are signed off (`git commit -s`). Work materially shaped by an AI
   tool is declared with a trailer in the form used by the
   [Koha Coding Guidelines](https://wiki.koha-community.org/wiki/Coding_Guidelines),
   and the human author stays responsible for the change:

   ```yaml
   Assisted-by: <ModelName> <Version> (<Vendor>)
   Signed-off-by: Jane Doe <jane@example.org>
   ```
