# Architecture

## Purpose

IntuneAccess is a PowerShell 7 module that converts separate Microsoft Graph objects into an auditable explanation of Intune administration, workload targeting and reported outcomes. It has no database, service, browser automation or hosted component.

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

The public surface covers the guided tenant-wide explorer, connection, administrator analysis, role assignment inspection, workload assignment impact, scope-tag auditing, managed-device explanation, Scoped permissions impact, administrator comparison, local snapshots, policy conflict analysis, structured export and HTML export.

### Graph read layer

`Invoke-IntuneAccessGraphRequest` is the only general Graph transport function. It allows GET requests, follows `@odata.nextLink`, handles `Retry-After`, retries transient server errors and converts authentication or consent failures into actionable errors.

No write method is accepted by the transport function.

### Source objects

Role definitions come from Graph rather than a local built in role table. Assignment, group, scope tag and resource IDs are retained.

The tenant explorer starts from Intune role assignments. It resolves only the Admin Groups, users, roles, Scope Groups, Scope Tags and permissions connected to those assignments. It does not enumerate every Microsoft Entra user or group.

The assignment collector uses a shared `IntuneAccess.WorkloadObject` and `IntuneAccess.WorkloadAssignment` model across configuration, compliance, endpoint security, applications, scripts, remediations and Windows updates. Raw Graph response shapes are normalised before the report consumes them.

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

The tenant collector reads role and assignment data once, enumerates direct and transitive user membership for the connected Admin Groups, and reuses the shared assignment evidence to calculate each administrator's permissions. The HTML explorer consumes that completed object and does not query Graph.

Workload assignment evidence is kept separate from delivery evidence. `ConfirmedAssignment` means the assignment configuration was returned by Graph. `ExcludedTarget` records an explicit exclusion. Neither state claims that a user or device received the workload. Unknown target types become `NotEvaluated`, and failed sources retain a per-source collection state and warning.

Operational evidence is normalised as `IntuneAccess.DeploymentOutcome`. A record keeps its source workload, reported state, category, detail, error code, timestamp, API version and device match state. Exact Intune device IDs are preferred. A unique device-name match is labelled `MatchedByName`; duplicate or absent names are not forced into a device relationship.

Device 360 and User 360 consume the same completed operational evidence. They do not issue hidden writes or convert an absent status record into success. Decimal Intune application error codes are retained and a hexadecimal form is added for troubleshooting.

Snapshots contain an allow-listed copy of completed evidence rather than the live Graph authentication context. The snapshot records an integrity hash and supports stable pseudonyms for tenant and identity values. Snapshot comparison calculates added, removed and changed records locally.

The audit collector reads the previous 30 days of Intune audit events through Graph v1.0. Snapshot changes are linked only where an audit resource ID matches a changed object ID. The absence of a matching event is not proof that no audited action occurred.

Policy analysis normalises observed Settings Catalog, endpoint security intent and supported legacy profile values by setting definition. Different values become a potential conflict only where exact included-target and filter evidence confirms overlap. Other possible intersections remain `NotEvaluated`.

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
6. Settings Catalog, script, remediation, assignment filter and Windows feature, quality and driver update assignment evidence used by the Assignment Explorer.
7. Application, PowerShell script and remediation device outcomes used by Device and User 360.
8. Settings Catalog and endpoint security intent setting instances used by Policy Conflicts.

Legacy configuration device status and application device status contracts carry Microsoft deprecation notices. They are isolated per workload and can fail without removing managed-device inventory or other successful outcome evidence.

If a beta property or enrichment call disappears, stable v1.0 assignment data is retained and the affected relationship becomes `NotEvaluated` with a warning. It must not infer a value.

## State and caching

Data is cached only in local variables for one command execution. Persistent snapshots are written only when the user supplies a snapshot path or baseline comparison. Group and scope tag data are reused within an analysis where practical.

## Output boundary

PowerShell objects are the data model. HTML, JSON and CSV generation consume those objects and do not run a second analysis. The tenant explorer contains local CSS and a small navigation script, uses no remote resources or network connection, and includes no access token. Tenant values are HTML encoded before insertion.
