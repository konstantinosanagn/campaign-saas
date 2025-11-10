# Scripts & Tooling

This project relies on a collection of executable helpers under `bin/` rather than custom shell scripts. Use the commands below for common tasks:

- `bin/setup` – prepare the app (install gems, yarn packages, set up DB)
- `bin/dev` – start Rails + webpack dev servers together
- `bin/rails` / `bin/rake` – run Rails or Rake commands with the correct environment
- `bin/brakeman`, `bin/bundler-audit`, `bin/rubocop` – perform security and lint checks (mirrors CI workflow)
- `bin/importmap audit` – scan JS dependencies while using importmap
- `bin/thrust` – production launcher used by the Dockerfile (wraps Puma configuration)

Add new operational scripts in this directory and update this doc so teammates know how to run them.

