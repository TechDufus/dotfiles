# Work Validation Reference

## Default Rule

Validate whenever the change is non-trivial, touches multiple files, adds or changes tests,
or used parallel or orchestrated execution. Skip only for clearly trivial edits and say why.

## Common Validation Commands

| Project Type | Typical Validation |
|--------------|--------------------|
| TypeScript / JavaScript | `npm run typecheck`, `npm run lint`, `npm test` |
| Python | `ruff check .`, `pytest` |
| Go | `go vet ./...`, `go test ./...` |
| Rust | `cargo check`, `cargo test` |
| Ansible | `ansible-lint`, `yamllint .` |
| Kubernetes YAML | `kubectl --dry-run=client -f <file>` |
| Terraform | `terraform validate`, `terraform plan` |
| Generic | language-specific syntax check, repo test target, or focused smoke check |

## Validation Rules

- Validate after parallel or orchestrated execution.
- Validate any time the change could easily regress behavior.
- If a preferred validation command is unavailable, run the closest practical check and say what
  could not be verified.
- Never claim completion when validation failed; report failure and next best path.
