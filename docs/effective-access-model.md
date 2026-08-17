# Effective access model

## Design rule

IntuneAccess reports only relationships that Graph returned or Microsoft documents. It does not fill missing relationships with assumptions.

## Source, evidence and conclusion

### Source

A source is an exact Graph object. Its ID is retained even when the normal display uses a friendly name.

Examples include a user, group, role definition, role assignment, scope tag and managed device.

### Evidence

Evidence describes a relationship observed in Graph data:

```text
User ID 1000
    > direct member of group ID 2000
        > group ID 2000 is a member on assignment ID 3000
            > assignment ID 3000 uses role definition ID 4000
                > role definition ID 4000 allows Microsoft.Intune_ManagedDevices_Read
```

### Conclusion

The resulting action is:

```text
Microsoft.Intune_ManagedDevices_Read = Allowed
```

The action retains every granting source. If two assignments return it, it appears once with two evidence records.

## Multiple assignments

Microsoft documents that Intune permissions from several groups are cumulative and that Intune RBAC has no deny permission that overrides an allowed permission.

Microsoft also introduced an opt in Scoped permissions setting in March 2026. Under the legacy behaviour, permissions in a shared category can merge across assignments with different scope tags. Under the preview behaviour, permissions stay within the assignment's scope context.

IntuneAccess 0.2 does not obtain this tenant setting from an established Graph contract. It therefore:

1. Unions confirmed exact actions for the top level permission list.
2. Retains assignment, scope group and scope tag context for every source.
3. Models legacy category merging and assignment-scoped behaviour separately with `Get-IntuneScopedPermissionImpact`.
4. Leaves `EffectiveState` as `NotEvaluated` when the tenant mode is `Unknown`.
5. Selects a model only when the caller explicitly supplies `LegacyMerged` or `Scoped`.
6. Avoids claiming that the top level list applies to every scope tag.

The impact model groups actions by the resource category derived from the original Graph action. Under the legacy model, confirmed actions in the same category are applied across the observed tag contexts in that category. Under the Scoped model, each action remains with its assignment tags. An assignment with no tag applies across the observed tag contexts. Missing scope-tag or administrator-membership evidence stays `NotEvaluated`.

## Admin Group membership

Direct group membership is confirmed evidence.

Microsoft documents special nested group behaviour that depends on whether unlicensed Intune administrators are enabled and whether the nested user has an Intune licence. IntuneAccess does not request licence detail permissions or infer the tenant setting. A nested only path is retained as evidence with `NotEvaluated` applicability.

## Scope (Groups)

`resourceScopes` is used for Microsoft Entra Scope (Groups) IDs. Beta `scopeType` identifies `allDevices`, `allLicensedUsers`, `allDevicesAndLicensedUsers` or `resourceScope`.

The `scopeMembers` beta property is retained as raw evidence. If it differs from `resourceScopes`, the result includes a warning and no undocumented replacement rule is invented.

For managed-device explanations, `resourceScope` is compared with both the Microsoft Entra device's transitive groups and the associated user's transitive groups. The evidence states whether the match came from `DeviceGroup` or `AssociatedUserGroup`. If either required membership path cannot be evaluated and no positive match exists, the scope result stays `NotEvaluated`.

## Scope (Tags)

An assignment with no scope tag has visibility across scope tags, subject to its role permissions and other scopes, according to current Microsoft documentation.

Supported Intune objects with no explicit tag are treated as using the Default scope tag, represented by ID `0` in the normalised audit data.

## No access path found

Failure to prove an Intune RBAC path is not proof of denial. Microsoft Entra roles can grant Intune access outside the model, and some resource scopes are not supported. Resource explanation therefore returns `NotEvaluated` unless it can prove a complete path.

## Behaviour labels

| Label | Meaning |
| --- | --- |
| `Allowed` | At least one confirmed direct Intune RBAC assignment returned the exact action. |
| `Confirmed` | The administrator was observed as a direct member of an assignment Admin Group. |
| `AccessPathFound` | Permission, Admin Group, device scope and scope tag evidence all matched. |
| `NotEvaluated` | Data or a documented rule was insufficient to reach a reliable conclusion. |
| `NotMatched` | A particular observed scope comparison did not match. This is not a tenant wide denial decision. |
| `PermissionReduction` | The action appears in the legacy model for a tag context but is not granted in the Scoped model for that context. |
| `NotGranted` | The complete simulated model contains no confirmed source for that action and tag context. This is not an access-denied decision for the tenant. |
