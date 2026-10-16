## What and why

## Checklist

- [ ] `make lint` passes
- [ ] `make test` passes (`make test-full` for big / cross-cutting changes)
- [ ] Applied to production and `make drift` is clean (or: not deployed yet, because …)
- [ ] No plain-text IPs / MACs / domain / secrets; app-config changes pulled with `make pull-config`
- [ ] Docs / ADR updated if behaviour or a decision changed
