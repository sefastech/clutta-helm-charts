# Contributing

Thank you for helping improve the Clutta Scan Helm chart.

## Before opening a change

- Open an issue first for behavior changes or new public values.
- Keep changes focused on one chart or repository concern.
- Do not add credentials, customer data, private network addresses, or
  environment-specific endpoints.
- Preserve the typed public Scan configuration. Internal detection policy does
  not belong in chart values.
- Do not modify an existing packaged chart. Published packages are immutable.

## Validate locally

Install Helm 3 or Helm 4, then run:

```bash
./scripts/validate.sh
```

The validation checks the values schema, chart rendering, package index
integrity, and public network boundary.

## Pull requests

Use a concise title such as `fix/clutta-scan: correct repository URLs` or
`update/clutta-scan: add a typed scheduling option`. Explain the user impact,
the validation performed, and any upgrade requirement.

Report vulnerabilities through [SECURITY.md](SECURITY.md), not a pull request.
