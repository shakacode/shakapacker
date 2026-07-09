# Security Policy

## Supported Versions

Security fixes are provided for the latest released major version of
Shakapacker.

| Version | Supported |
| ------- | --------- |
| 10.x    | Yes       |
| < 10    | No        |

Pre-release versions are supported only until the corresponding stable release
is published. Please upgrade to a supported release before reporting an issue
that affects an unsupported version.

ShakaCode can provide security updates for prior releases on request. [Get in
touch to discuss your needs](https://meetings.hubspot.com/justingordon/30-minute-consultation).

## Reporting a Vulnerability

Do not report security vulnerabilities through public GitHub issues,
discussions, pull requests, or social media.

Instead, use [GitHub's private vulnerability reporting form](https://github.com/shakacode/shakapacker/security/advisories/new) for this repository. The report is visible only to repository maintainers until a coordinated disclosure is ready.

Please include:

- A description of the vulnerability and its potential impact.
- Affected Shakapacker, Ruby, Rails, Node.js, webpack, and Rspack versions.
- Steps to reproduce, preferably as a minimal application or proof of concept.
- Any suggested mitigation or fix, if available.

We will acknowledge receipt within five business days, assess the report, and
work with you on a coordinated disclosure and fix. Please give us reasonable
time to address the issue before sharing details publicly.

## Scope

This policy covers the Ruby gem, the published npm packages, and code in this
repository. Security issues in an application's own configuration or in
third-party dependencies should be reported to the relevant project unless
they result from Shakapacker's behavior or defaults.
