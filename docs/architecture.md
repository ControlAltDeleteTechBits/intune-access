# Architecture

## Purpose

IntuneAccess is a PowerShell 7 module that converts separate Microsoft Graph objects into an auditable explanation of Intune RBAC access. It has no database, service, browser automation or hosted component.

## Layers

```text
Public commands
    > Graph read layer
        > normalised source objects
            > relationship evidence
                > conservative conclusions
                    > PowerShell objects or local HTML
```

### Public commands

The public surface covers connection, administrator analysis, role assignment inspection, scope-tag auditing, managed-device explanation, Scoped permissions impact, administrator comparison, structured export and HTML export.

### Graph read layer

`Invoke-IntuneAccessGraphRequest` is the only general Graph transport function. It allows GET requests, follows `@odata.nextLink`, handles `Retry-After`, retries transient server errors and converts authentication or consent failures into actionable errors.

No write method is accepted by the transport function.

### Source objects

Role definitions come from Graph rather than a local built in role table. Assignment, group, scope tag and resource IDs are retained.

### Evidence

The core evidence chain is:

```text
User
    > member of Admin Group
        > Admin Group listed on role assignment
            > assignment uses role definition
                > role definition returns allowed action
```

Scope groups and scope tags are attached to the assignment evidence rather than flattened into an unsupported tenant wide claim.

Scoped permission impact is derived from the same assignment evidence. The legacy and Scoped models are kept side by side, and the active tenant mode remains unknown unless supplied by the caller.

Administrator comparison consumes two completed access objects. JSON and CSV export consume completed evidence objects and do not query Graph again.

### Conclusions

An exact allowed action is `Allowed` when at least one confirmed direct Admin Group path supplies it. A nested only path is `NotEvaluated`. Duplicate sources are retained.

The managed-device explanation reads stable device identity and relationships from v1.0, then adds scope-tag IDs through isolated beta enrichment. It also checks Microsoft Entra device-group membership and associated-user group membership. It returns `AccessPathFound` only when every required link matches. Every other result is `NotEvaluated`, not access denied.

## API versions

Role definitions, stable role assignment fields, users, groups, tenant data and Microsoft Entra device membership use Microsoft Graph v1.0. Assignment IDs, names, administrator groups and resource scope groups remain available when beta enrichment fails.

The following properties require isolated beta calls:

1. `roleScopeTagIds` on role assignments.
2. `scopeType` on role assignments.
3. `roleScopeTagIds` enrichment on managed devices and audited Intune resources. Stable IDs and names come from v1.0 where that contract exists.
4. The role scope tag collection.
5. Settings Catalog, endpoint security policy, remediation and device health script identity and scope-tag data used by the optional extended audit.

If a beta property or enrichment call disappears, stable v1.0 assignment data is retained and the affected relationship becomes `NotEvaluated` with a warning. It must not infer a value.

## State and caching

Data is cached only in local variables for one command execution. There is no persistent tenant cache. Group and scope tag data are reused within an analysis where practical.

## Output boundary

PowerShell objects are the data model. HTML, JSON and CSV generation consume those objects and do not run a second analysis. The HTML contains CSS only, uses no remote resources and includes no access token.
