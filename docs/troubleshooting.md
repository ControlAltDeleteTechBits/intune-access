# Troubleshooting

## Microsoft.Graph.Authentication is missing

Install the smallest required Graph SDK module:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

Restart PowerShell 7 and import IntuneAccess again.

## No Graph session is connected

Run:

```powershell
Connect-IntuneAccess
```

Select additional features when using the audit or managed device commands.

## A delegated scope is missing

Reconnect with the feature named by the error:

```powershell
Connect-IntuneAccess -Feature Core, ScopeTagAudit
```

or:

```powershell
Connect-IntuneAccess -Feature Core, ManagedDeviceAccess
```

## HTTP 403

Graph consent and the signed in administrator's Intune rights are separate checks. Confirm:

1. The delegated Graph scope has tenant consent where required.
2. The signed in user has an Intune role that can read the requested data.
3. The tenant has an active Intune licence.

Do not replace the documented read permission with a broad directory or write permission.

## HTTP 401

The token may have expired. Run `Connect-IntuneAccess` again. Tokens are never stored by IntuneAccess.

## HTTP 429 or a transient server error

The Graph request layer follows `Retry-After` when available and otherwise uses bounded exponential backoff. Use `-Verbose` to see retry timing.

## A group is unresolved

The raw group ID remains in the result. Check `GroupMember.Read.All` consent, hidden membership restrictions and whether the group still exists.

## Nested membership is NotEvaluated

This is expected. Current Microsoft documentation describes licence dependent behaviour for nested Admin Groups. IntuneAccess does not infer the licence or tenant setting.

## Several devices have the same name

No device is selected. Device display names are not unique. Rename or query the devices in Intune, then use an exact unique name for the command.

## HTML export refuses to replace a file

Use `-Force` only after confirming the destination:

```powershell
$access | Export-IntuneAccessReport -Path '.\report.html' -Force
```

## Collecting diagnostic information

Use `-Verbose`. Do not post full report files, tenant IDs, user principal names or Graph error payloads in a public issue. IntuneAccess does not include file logging in version 0.2.
