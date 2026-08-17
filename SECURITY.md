# Security policy

## Supported version

Version 1.0 is the supported stable release. Security fixes are applied to the latest 1.x release.

## Reporting a security issue

Open a private security advisory in the project repository when that facility is available. Do not publish tenant data in a public issue.

Include the smallest reproducible example. Remove or replace:

1. User principal names.
2. Tenant and object IDs.
3. Group, policy and device names.
4. Access tokens, authorisation headers and correlation data that could identify a tenant.

If a private channel is not available, open a public issue containing no tenant data and ask a maintainer for a secure contact method.

## Data handling

IntuneAccess processes Graph responses in the local PowerShell process. It has no telemetry, analytics, remote report service or project controlled storage.

The module must never write access tokens or authorisation headers to output, reports, errors or logs. Generated reports can contain sensitive administrative configuration and must be protected by the operator.

## Permission policy

The project accepts read only Graph permissions for version 1.x. A request for a write permission is a release blocker unless the project scope and major version are deliberately changed after public review.
