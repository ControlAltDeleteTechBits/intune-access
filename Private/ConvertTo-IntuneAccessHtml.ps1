function ConvertTo-IntuneAccessHtml {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [object] $Access
    )

    function ConvertTo-EncodedText {
        param([AllowNull()] [object] $Value)
        return [System.Net.WebUtility]::HtmlEncode([string] $Value)
    }

    function ConvertTo-Slug {
        param([AllowNull()] [object] $Value)
        $slug = ([string] $Value).ToLowerInvariant() -replace '[^a-z0-9]+', '-'
        $slug = $slug.Trim('-')
        if ([string]::IsNullOrWhiteSpace($slug)) { return 'item' }
        return $slug
    }

    function Get-EmbeddedAsset {
        param(
            [Parameter(Mandatory)] [string] $RelativePath,
            [Parameter(Mandatory)] [string] $MimeType
        )

        $assetPath = Join-Path -Path $script:IntuneAccessModuleRoot -ChildPath $RelativePath
        if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) { return '' }
        $base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($assetPath))
        return "data:$MimeType;base64,$base64"
    }

    $user = Get-IntuneAccessProperty $Access 'User'
    $tenant = Get-IntuneAccessProperty $Access 'Tenant'
    $assignments = @(Get-IntuneAccessProperty $Access 'RoleAssignments' @())
    $permissions = @(Get-IntuneAccessProperty $Access 'EffectivePermissions' @())
    $warnings = @(Get-IntuneAccessProperty $Access 'Warnings' @())
    $generated = [DateTimeOffset] (Get-IntuneAccessProperty $Access 'GeneratedAt' ([DateTimeOffset]::Now))
    $generatedText = $generated.ToString('dd MMMM yyyy HH:mm zzz', [Globalization.CultureInfo]::GetCultureInfo('en-GB'))
    $generatedDate = $generated.ToString('dd MMMM yyyy', [Globalization.CultureInfo]::GetCultureInfo('en-GB'))
    $generatedTime = $generated.ToString('HH:mm zzz', [Globalization.CultureInfo]::GetCultureInfo('en-GB'))
    $userPrincipalName = [string] (Get-IntuneAccessProperty $user 'UserPrincipalName')
    $userDisplayName = [string] (Get-IntuneAccessProperty $user 'DisplayName' $userPrincipalName)
    $tenantName = [string] (Get-IntuneAccessProperty $tenant 'DisplayName' 'Unknown tenant')
    $reviewCount = $warnings.Count

    $spaceFont = Get-EmbeddedAsset -RelativePath 'Assets\Fonts\SpaceGrotesk-Variable.ttf' -MimeType 'font/ttf'
    $plexRegular = Get-EmbeddedAsset -RelativePath 'Assets\Fonts\IBMPlexMono-Regular.ttf' -MimeType 'font/ttf'
    $plexSemiBold = Get-EmbeddedAsset -RelativePath 'Assets\Fonts\IBMPlexMono-SemiBold.ttf' -MimeType 'font/ttf'
    $iconUser = Get-EmbeddedAsset -RelativePath 'Assets\Icons\user-circle.svg' -MimeType 'image/svg+xml'
    $iconGroups = Get-EmbeddedAsset -RelativePath 'Assets\Icons\users-three.svg' -MimeType 'image/svg+xml'
    $iconRole = Get-EmbeddedAsset -RelativePath 'Assets\Icons\shield-check.svg' -MimeType 'image/svg+xml'
    $iconDevices = Get-EmbeddedAsset -RelativePath 'Assets\Icons\devices.svg' -MimeType 'image/svg+xml'
    $iconApps = Get-EmbeddedAsset -RelativePath 'Assets\Icons\app-window.svg' -MimeType 'image/svg+xml'
    $iconArrow = Get-EmbeddedAsset -RelativePath 'Assets\Icons\arrow-right.svg' -MimeType 'image/svg+xml'
    $iconTenant = Get-EmbeddedAsset -RelativePath 'Assets\Icons\buildings.svg' -MimeType 'image/svg+xml'
    $iconCalendar = Get-EmbeddedAsset -RelativePath 'Assets\Icons\calendar-blank.svg' -MimeType 'image/svg+xml'
    $iconLock = Get-EmbeddedAsset -RelativePath 'Assets\Icons\lock.svg' -MimeType 'image/svg+xml'
    $iconQuestion = Get-EmbeddedAsset -RelativePath 'Assets\Icons\question.svg' -MimeType 'image/svg+xml'
    $iconLightbulb = Get-EmbeddedAsset -RelativePath 'Assets\Icons\lightbulb.svg' -MimeType 'image/svg+xml'

    $fontCss = if ($spaceFont -and $plexRegular -and $plexSemiBold) {
        "@font-face{font-family:'Space Grotesk';src:url('$spaceFont') format('truetype');font-weight:300 700;font-style:normal;font-display:swap}@font-face{font-family:'IBM Plex Mono';src:url('$plexRegular') format('truetype');font-weight:400;font-style:normal;font-display:swap}@font-face{font-family:'IBM Plex Mono';src:url('$plexSemiBold') format('truetype');font-weight:600;font-style:normal;font-display:swap}"
    }
    else { '' }

    $mapRows = [System.Text.StringBuilder]::new()
    $pathIndex = 0
    foreach ($assignment in $assignments) {
        $pathIndex++
        $roleDefinition = Get-IntuneAccessProperty $assignment 'RoleDefinition'
        $roleName = [string] (Get-IntuneAccessProperty $roleDefinition 'DisplayName' 'Role not returned')
        $roleType = if ((Get-IntuneAccessProperty $roleDefinition 'IsBuiltIn') -eq $true) { 'Built-in role' } elseif ((Get-IntuneAccessProperty $roleDefinition 'IsBuiltIn') -eq $false) { 'Custom role' } else { 'Role type not returned' }
        $applicability = [string] (Get-IntuneAccessProperty $assignment 'Applicability' 'NotEvaluated')
        $confirmed = $applicability -eq 'Confirmed'
        $pathClass = if ($confirmed) { 'path-confirmed' } else { 'path-unknown' }
        $pathStatus = if ($confirmed) { 'Confirmed access path' } else { 'Not evaluated' }

        $adminGroups = @(Get-IntuneAccessProperty $assignment 'AdminGroups' @())
        $adminEvidence = @(Get-IntuneAccessProperty $assignment 'AdminGroupEvidence' @())
        $groupName = if ($adminGroups.Count -gt 0) { [string] (Get-IntuneAccessProperty $adminGroups[0] 'DisplayName' 'Unnamed group') } else { 'No group returned' }
        $groupExtra = if ($adminGroups.Count -gt 1) { "+$($adminGroups.Count - 1) more group" } elseif (@($adminEvidence | Where-Object MembershipType -eq 'Nested').Count -gt 0) { 'Microsoft Entra group, nested' } else { 'Microsoft Entra group' }

        $scopeGroups = @(Get-IntuneAccessProperty $assignment 'ScopeGroups' @())
        $scopeTags = @(Get-IntuneAccessProperty $assignment 'ScopeTags' @())
        $scopeType = [string] (Get-IntuneAccessProperty $assignment 'ScopeType' 'resourceScope')
        $scopeParts = [System.Collections.Generic.List[string]]::new()
        foreach ($scopeGroup in $scopeGroups) { $scopeParts.Add((ConvertTo-EncodedText (Get-IntuneAccessProperty $scopeGroup 'DisplayName' 'Unnamed scope group'))) }
        if ($scopeGroups.Count -eq 0) {
            $scopeLabel = switch ($scopeType) {
                'allDevices' { 'All devices' }
                'allLicensedUsers' { 'All licensed users' }
                'allDevicesAndLicensedUsers' { 'All devices and licensed users' }
                default { 'No scope group returned' }
            }
            $scopeParts.Add((ConvertTo-EncodedText $scopeLabel))
        }
        foreach ($scopeTag in $scopeTags) { $scopeParts.Add((ConvertTo-EncodedText (Get-IntuneAccessProperty $scopeTag 'DisplayName' 'Unnamed scope tag'))) }
        if ($scopeTags.Count -eq 0) { $scopeParts.Add('All tags') }
        $scopeHtml = @($scopeParts | ForEach-Object { "<span>$_</span>" }) -join ''

        $assignmentActions = @(Get-IntuneAccessProperty $assignment 'Permissions' @())
        $friendlyActions = @($assignmentActions | ForEach-Object { ConvertFrom-IntuneAccessActionName -Action ([string] $_) })
        $families = @($friendlyActions.Resource | Where-Object { $_ } | Select-Object -Unique)
        $familyName = if ($families.Count -eq 0) { 'No permissions returned' } elseif ($families.Count -eq 1) { [string] $families[0] } else { "$($families.Count) permission families" }
        $familyDetail = if ($assignmentActions.Count -eq 1) { '1 observed action' } else { "$($assignmentActions.Count) observed actions" }
        $familyIcon = if ($familyName -match 'App') { $iconApps } else { $iconDevices }
        $rawActions = if ($friendlyActions.Count -gt 0) {
            @($friendlyActions | ForEach-Object { '<code>{0}</code>' -f (ConvertTo-EncodedText $_.RawAction) }) -join ''
        }
        else { '<span class="muted">No raw permission action was returned.</span>' }

        $null = $mapRows.AppendLine(('<details class="map-path {0}" id="path-{1}"><summary aria-label="Open evidence for {2}">' -f $pathClass, $pathIndex, (ConvertTo-EncodedText $roleName)))
        $null = $mapRows.AppendLine(('<span class="path-card group-card"><img src="{0}" alt=""><span><strong>{1}</strong><small>{2}</small></span></span>' -f $iconGroups, (ConvertTo-EncodedText $groupName), (ConvertTo-EncodedText $groupExtra)))
        $null = $mapRows.AppendLine(('<span class="path-card role-card"><img src="{0}" alt=""><span><strong>{1}</strong><small>{2}</small></span></span>' -f $iconRole, (ConvertTo-EncodedText $roleName), (ConvertTo-EncodedText $roleType)))
        $null = $mapRows.AppendLine(('<span class="scope-card">{0}</span>' -f $scopeHtml))
        $null = $mapRows.AppendLine(('<span class="path-card family-card"><img src="{0}" alt=""><span><strong>{1}</strong><small>{2}</small></span></span></summary>' -f $familyIcon, (ConvertTo-EncodedText $familyName), (ConvertTo-EncodedText $familyDetail)))
        $null = $mapRows.AppendLine('<div class="path-evidence">')
        $null = $mapRows.AppendLine(('<div><span class="field-label">Assignment</span><strong>{0}</strong><code>{1}</code></div>' -f (ConvertTo-EncodedText (Get-IntuneAccessProperty $assignment 'Name' 'Unnamed assignment')), (ConvertTo-EncodedText (Get-IntuneAccessProperty $assignment 'Id' 'No identifier returned'))))
        $null = $mapRows.AppendLine(('<div><span class="field-label">Evaluation</span><strong>{0}</strong><span class="evidence-status">{1}</span></div>' -f (ConvertTo-EncodedText $pathStatus), (ConvertTo-EncodedText $applicability)))
        $null = $mapRows.AppendLine(('<div><span class="field-label">Observed actions</span><div class="raw-actions">{0}</div></div>' -f $rawActions))
        $null = $mapRows.AppendLine('</div></details>')
    }
    if ($assignments.Count -eq 0) {
        $null = $mapRows.AppendLine('<div class="empty-state">No matching role assignments were observed for this administrator.</div>')
    }

    $permissionGroups = @($permissions | Group-Object -Property Resource | Sort-Object -Property Name)
    $filterControls = [System.Text.StringBuilder]::new()
    $filterCss = [System.Text.StringBuilder]::new()
    $permissionRows = [System.Text.StringBuilder]::new()
    $null = $filterControls.AppendLine('<input class="family-filter" type="radio" name="family-filter" id="family-all" checked><label for="family-all">All <span>' + $permissions.Count + '</span></label>')
    foreach ($group in $permissionGroups) {
        $slug = ConvertTo-Slug $group.Name
        $null = $filterControls.AppendLine(('<input class="family-filter" type="radio" name="family-filter" id="family-{0}"><label for="family-{0}">{1} <span>{2}</span></label>' -f $slug, (ConvertTo-EncodedText $group.Name), $group.Count))
        $null = $filterCss.AppendLine(('.index-section:has(#family-{0}:checked) .permission-entry{{display:none}}.index-section:has(#family-{0}:checked) .family-{0}{{display:block}}' -f $slug))
    }

    foreach ($permission in @($permissions | Sort-Object -Property Resource, Operation)) {
        $slug = ConvertTo-Slug $permission.Resource
        $stateClass = if ($permission.State -eq 'Allowed') { 'status-allowed' } else { 'status-unknown' }
        $sourceName = @($permission.GrantedBy | Select-Object -First 1).RoleDefinitionName
        if ([string]::IsNullOrWhiteSpace([string] $sourceName)) { $sourceName = 'Observed RBAC source' }
        $grantRows = if (@($permission.GrantedBy).Count -gt 0) {
            @($permission.GrantedBy | ForEach-Object {
                '<div class="grant-path"><span>{0}</span><img src="{1}" alt=""><span>{2}</span><img src="{1}" alt=""><span>{3}</span></div>' -f
                    (ConvertTo-EncodedText $_.RoleDefinitionName), $iconArrow,
                    (ConvertTo-EncodedText $_.RoleAssignmentName), (ConvertTo-EncodedText $_.Applicability)
            }) -join ''
        }
        else { '<span class="muted">No granting source was returned.</span>' }

        $null = $permissionRows.AppendLine(('<details class="permission-entry family-{0}"><summary><span>{1}</span><span>{2}</span><span class="permission-state {3}"><i></i>{4}</span><span>{5}</span></summary>' -f
            $slug, (ConvertTo-EncodedText $permission.Resource), (ConvertTo-EncodedText $permission.Operation), $stateClass,
            (ConvertTo-EncodedText $permission.State), (ConvertTo-EncodedText $sourceName)))
        $null = $permissionRows.AppendLine(('<div class="permission-evidence"><code>{0}</code><div>{1}</div></div></details>' -f (ConvertTo-EncodedText $permission.RawAction), $grantRows))
    }
    if ($permissions.Count -eq 0) {
        $null = $permissionRows.AppendLine('<div class="empty-state">No effective Intune RBAC permission was confirmed.</div>')
    }

    $warningHtml = if ($warnings.Count -gt 0) {
        @($warnings | ForEach-Object { '<li>{0}</li>' -f (ConvertTo-EncodedText $_) }) -join ''
    }
    else { '<li>No calculation warnings were produced.</li>' }

    $graphScopes = @(Get-IntuneAccessProperty $Access 'GraphPermissionsUsed' @())
    $graphScopeHtml = @($graphScopes | Sort-Object | ForEach-Object { '<code>{0}</code>' -f (ConvertTo-EncodedText $_) }) -join ''
    $title = "IntuneAccess report - $userPrincipalName"

    return @"
<!doctype html>
<html lang="en-GB">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>$(ConvertTo-EncodedText $title)</title>
<style>
$fontCss
:root{--paper:#fbfbfa;--surface:#fff;--ink:#101114;--muted:#555b66;--soft:#777d87;--line:#d8d9dc;--line-dark:#afb2b8;--yellow:#ffd400;--yellow-deep:#c9a900;--blue:#0667c9;--unknown:#9aa0a8;--font-display:'Space Grotesk','Segoe UI',Arial,sans-serif;--font-mono:'IBM Plex Mono',Consolas,monospace}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--paper);color:var(--ink);font-family:var(--font-display);font-size:14px;line-height:1.45}button,input,summary{font:inherit}img{display:block}.shell{width:min(1392px,calc(100% - 56px));margin:0 auto}.topbar{height:60px;border-bottom:1px solid var(--line);background:rgba(251,251,250,.97);display:flex;align-items:center}.topbar-inner{width:100%;display:flex;align-items:center;justify-content:space-between;gap:24px}.brand-cluster,.report-meta,.meta-pill{display:flex;align-items:center}.brand-cluster{gap:24px}.brand{font-size:23px;font-weight:700;letter-spacing:-.045em}.brand-divider{width:1px;height:24px;background:var(--line)}.report-mode{font-size:18px;letter-spacing:-.02em}.read-only{display:flex;align-items:center;gap:10px}.read-only i{width:10px;height:10px;border-radius:50%;background:var(--yellow)}.report-meta{gap:0}.meta-pill{gap:10px;padding:0 24px;border-left:1px solid var(--line);min-height:28px;white-space:nowrap}.meta-pill img{width:19px;height:19px}.meta-pill strong{font-weight:600;margin-left:5px}.report-header{display:grid;grid-template-columns:minmax(0,.88fr) minmax(620px,1.22fr);gap:64px;align-items:center;padding:36px 0 38px}.report-header h1{font-size:58px;line-height:.95;letter-spacing:-.065em;margin:0 0 14px;font-weight:700}.report-header p{font-size:17px;line-height:1.5;color:var(--muted);max-width:520px;margin:0}.identity-strip{border:1px solid var(--line);background:var(--surface);display:grid;grid-template-columns:1.45fr .75fr 1.05fr .78fr;min-height:112px}.identity-cell{padding:19px 24px;border-left:1px solid var(--line);display:flex;flex-direction:column;justify-content:center;min-width:0}.identity-cell:first-child{border-left:0}.identity-user{display:grid;grid-template-columns:40px minmax(0,1fr);gap:13px;align-items:center}.identity-user img{width:38px;height:38px}.field-label{display:block;font:600 11px/1.2 var(--font-mono);letter-spacing:.045em;text-transform:uppercase;color:var(--muted);margin-bottom:8px}.identity-cell strong{font-size:17px;line-height:1.25;letter-spacing:-.02em;overflow-wrap:anywhere}.identity-cell small{font-size:14px;color:var(--muted);margin-top:3px}.map-section{padding:12px 0 27px}.map-headings{display:grid;grid-template-columns:150px minmax(210px,1.05fr) minmax(220px,1.08fr) minmax(190px,.9fr) minmax(220px,1.05fr);gap:54px;padding:0 10px 20px;font:600 12px/1.2 var(--font-mono);letter-spacing:.06em;text-transform:uppercase;color:var(--muted)}.map-layout{display:grid;grid-template-columns:150px minmax(0,1fr);gap:54px;align-items:stretch}.administrator-node{display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;min-height:302px;position:relative}.administrator-node:after{content:"";position:absolute;right:-54px;top:50%;width:54px;border-top:2px solid var(--yellow)}.administrator-avatar{width:88px;height:88px;border:1px solid var(--line);border-radius:50%;display:grid;place-items:center;background:var(--surface);margin-bottom:8px}.administrator-avatar img{width:47px;height:47px}.administrator-node strong{font-size:17px}.administrator-node small{color:var(--muted);font-size:12px;overflow-wrap:anywhere;max-width:165px}.administrator-node .user-type{font:400 11px/1 var(--font-mono);border:1px solid var(--line);padding:7px 12px;margin-top:9px;background:var(--surface)}.path-stack{display:grid;gap:13px}.map-path{position:relative}.map-path>summary{list-style:none;display:grid;grid-template-columns:minmax(210px,1.05fr) minmax(220px,1.08fr) minmax(190px,.9fr) minmax(220px,1.05fr);gap:54px;align-items:center;min-height:92px;cursor:pointer;position:relative}.map-path>summary::-webkit-details-marker{display:none}.path-card{min-height:72px;border:1px solid var(--line);background:var(--surface);display:grid;grid-template-columns:38px minmax(0,1fr);gap:13px;align-items:center;padding:14px 18px;position:relative}.path-card img{width:31px;height:31px}.path-card strong{display:block;font-size:16px;line-height:1.2;letter-spacing:-.025em}.path-card small{display:block;color:var(--muted);font-size:13px;margin-top:5px}.path-card:not(.family-card):after,.scope-card:after{content:"";position:absolute;right:-54px;top:50%;width:54px;border-top:2px solid var(--yellow)}.path-card:not(.family-card):before,.scope-card:before{content:"";position:absolute;right:-54px;top:calc(50% - 7px);width:12px;height:12px;border-top:2px solid var(--yellow);border-right:2px solid var(--yellow);transform:rotate(45deg);z-index:2}.scope-card{min-height:72px;border-left:1px solid var(--line-dark);padding:5px 16px;display:flex;flex-direction:column;justify-content:center;position:relative;color:var(--muted)}.scope-card span{display:block;font-size:12px;line-height:1.55}.path-unknown .path-card:not(.family-card):after,.path-unknown .scope-card:after{border-top:2px dashed var(--unknown)}.path-unknown .path-card:not(.family-card):before,.path-unknown .scope-card:before{border-color:var(--unknown)}.map-path[open]>summary .path-card{border-color:var(--ink)}.path-evidence{margin:0 0 6px;border:1px solid var(--line);border-top:3px solid var(--yellow);background:#f6f6f3;padding:18px 22px;display:grid;grid-template-columns:1fr .7fr 1.5fr;gap:30px}.path-unknown .path-evidence{border-top-color:var(--unknown)}.path-evidence strong,.path-evidence code{display:block}.path-evidence code,.raw-actions code{font:400 11px/1.55 var(--font-mono);color:var(--muted);overflow-wrap:anywhere}.evidence-status{font:600 11px/1.2 var(--font-mono);text-transform:uppercase}.map-legend{display:flex;align-items:center;gap:34px;border-bottom:1px solid var(--line);padding:22px 4px 25px;color:var(--muted);font-size:13px}.legend-key{display:flex;align-items:center;gap:10px}.legend-key i{display:block;width:39px;border-top:2px solid var(--yellow)}.legend-key.unknown i{border-top:2px dashed var(--unknown)}.legend-note{margin-left:auto;display:flex;align-items:center;gap:8px}.legend-note img{width:18px;height:18px}.index-section{display:grid;grid-template-columns:minmax(220px,.58fr) minmax(560px,1.42fr) minmax(290px,.68fr);gap:30px;padding:26px 0 24px}.index-title h2,.review-note h2{font-size:22px;line-height:1.15;letter-spacing:-.035em;margin:0 0 5px}.index-title p,.review-note p{color:var(--muted);margin:0;font-size:13px}.filter-list{margin-top:42px;border:1px solid var(--line);background:var(--surface)}.family-filter{position:absolute;opacity:0;pointer-events:none}.family-filter+label{display:flex;justify-content:space-between;align-items:center;padding:11px 14px;border-bottom:1px solid var(--line);cursor:pointer;font-weight:600}.family-filter+label span{font-family:var(--font-mono);font-size:12px}.family-filter:checked+label{border-left:4px solid var(--yellow);padding-left:10px;background:#f7f6ee}.family-filter:focus-visible+label{outline:2px solid var(--blue);outline-offset:2px}.permission-table{border-top:1px solid var(--line);margin-top:31px}.permission-head,.permission-entry>summary{display:grid;grid-template-columns:1.1fr .95fr .72fr 1.25fr;gap:18px;align-items:center}.permission-head{font:600 11px/1.2 var(--font-mono);letter-spacing:.04em;text-transform:uppercase;color:var(--muted);padding:0 14px 11px}.permission-entry{border:1px solid var(--line);border-top:0;background:var(--surface)}.permission-entry>summary{list-style:none;cursor:pointer;padding:9px 14px;font-size:12px;min-height:36px}.permission-entry>summary::-webkit-details-marker{display:none}.permission-entry[open]>summary{background:#f7f6ee}.permission-state{display:flex;align-items:center;gap:8px}.permission-state i{width:8px;height:8px;border-radius:50%;background:var(--yellow)}.permission-state.status-unknown i{background:var(--unknown)}.permission-evidence{border-top:1px solid var(--line);background:#f6f6f3;padding:13px 15px}.permission-evidence>code{font:400 11px/1.5 var(--font-mono);color:var(--muted);overflow-wrap:anywhere}.grant-path{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-top:10px}.grant-path span{font-size:12px}.grant-path img{width:15px;height:15px}.review-note{border-left:1px solid var(--line);padding:2px 0 0 30px}.review-heading{display:grid;grid-template-columns:46px minmax(0,1fr);gap:16px;align-items:center;margin-bottom:14px}.review-icon{width:46px;height:46px;background:var(--yellow);display:grid;place-items:center}.review-icon img{width:27px;height:27px}.review-note ul{padding-left:18px;color:var(--muted);font-size:12px}.review-note li+li{margin-top:8px}.method-detail{border:1px solid var(--line);margin-top:17px;background:var(--surface)}.method-detail summary{cursor:pointer;list-style:none;padding:10px 13px;font-weight:600}.method-detail summary::-webkit-details-marker{display:none}.method-content{padding:0 13px 13px;color:var(--muted);font-size:12px}.graph-scopes{display:flex;flex-wrap:wrap;gap:5px}.graph-scopes code{font:400 10px/1.25 var(--font-mono);border:1px solid var(--line);padding:4px;background:#f6f6f3}.report-footer{border-top:1px solid var(--line);display:flex;justify-content:space-between;gap:24px;padding:17px 0 24px;color:var(--muted);font-size:12px}.muted{color:var(--muted)}.empty-state{border:1px dashed var(--line-dark);padding:28px;color:var(--muted);background:var(--surface)}
$filterCss
.identity-user>div{min-width:0}.identity-cell small{display:block;min-width:0;max-width:100%;overflow-wrap:anywhere;word-break:break-word}
summary:focus{outline:none}summary:focus-visible{outline:2px solid var(--blue);outline-offset:3px}
@media(max-width:1320px){.report-meta .meta-pill:first-child{display:none}.meta-pill{padding:0 18px}.map-headings{gap:44px}.map-layout{gap:44px}.administrator-node:after{right:-44px;width:44px}.map-path>summary{gap:44px}.path-card:not(.family-card):after,.scope-card:after{right:-44px;width:44px}.path-card:not(.family-card):before,.scope-card:before{right:-44px}}
@media(max-width:1050px){.report-header{grid-template-columns:1fr}.map-headings{display:none}.map-layout{grid-template-columns:1fr}.administrator-node{min-height:auto;align-items:flex-start;text-align:left;display:grid;grid-template-columns:58px 1fr;column-gap:12px;margin-bottom:10px}.administrator-avatar{width:58px;height:58px;grid-row:1/4;margin:0}.administrator-avatar img{width:34px;height:34px}.administrator-node:after{display:none}.administrator-node small{max-width:none}.administrator-node .user-type{width:max-content}.map-path>summary{grid-template-columns:1fr 1fr;gap:10px}.path-card:not(.family-card):after,.path-card:not(.family-card):before,.scope-card:after,.scope-card:before{display:none}.index-section{grid-template-columns:240px 1fr}.review-note{grid-column:1/-1;border-left:0;border-top:1px solid var(--line);padding:24px 0 0}.filter-list{margin-top:20px}}
@media(max-width:720px){.shell{width:min(100% - 28px,1392px)}.topbar{height:auto;padding:15px 0}.topbar-inner,.brand-cluster{align-items:flex-start}.brand-cluster{gap:12px;flex-wrap:wrap}.brand{font-size:20px}.report-mode{font-size:16px}.read-only{width:100%}.report-meta{display:none}.report-header{padding:28px 0}.report-header h1{font-size:46px}.identity-strip{grid-template-columns:1fr 1fr}.identity-cell{border-bottom:1px solid var(--line)}.identity-cell:nth-child(3){border-left:0}.map-path>summary{grid-template-columns:1fr}.scope-card{border:1px solid var(--line);padding:14px 18px}.path-evidence{grid-template-columns:1fr}.map-legend{align-items:flex-start;flex-wrap:wrap}.legend-note{margin-left:0;width:100%}.index-section{grid-template-columns:1fr}.filter-list{margin-top:14px}.permission-list{min-width:0}.permission-head{display:none}.permission-table{overflow:visible;margin-top:0}.permission-entry>summary{min-width:0;grid-template-columns:1fr 1fr;gap:8px 16px;padding:12px 14px}.report-footer{flex-direction:column}}
@media print{body{background:#fff}.topbar{position:static}.family-filter+label{display:none}.family-filter:checked+label{display:flex}.map-path .path-evidence,.permission-entry .permission-evidence{display:block}.map-path,.permission-entry{break-inside:avoid}.report-footer{padding-bottom:0}}
</style>
</head>
<body>
<header class="topbar"><div class="shell topbar-inner">
  <div class="brand-cluster"><span class="brand">IntuneAccess</span><span class="brand-divider"></span><span class="report-mode">Signal Atlas</span><span class="read-only"><i></i>Read-only report</span></div>
  <div class="report-meta"><span class="meta-pill"><img src="$iconTenant" alt="">Tenant:<strong>$(ConvertTo-EncodedText $tenantName)</strong></span><span class="meta-pill"><img src="$iconCalendar" alt="">Generated:<strong>$(ConvertTo-EncodedText $generatedText)</strong></span><span class="meta-pill"><img src="$iconLock" alt="">Read-only</span></div>
</div></header>
<main class="shell">
  <section class="report-header" aria-labelledby="access-map-title">
    <div><h1 id="access-map-title">Access map</h1><p>Trace how this administrator's access is granted through groups, roles, scopes and the actions they can perform.</p></div>
    <div class="identity-strip">
      <div class="identity-cell identity-user"><img src="$iconUser" alt=""><div><span class="field-label">Administrator</span><strong>$(ConvertTo-EncodedText $userDisplayName)</strong><small>$(ConvertTo-EncodedText $userPrincipalName)</small></div></div>
      <div class="identity-cell"><span class="field-label">Tenant</span><strong>$(ConvertTo-EncodedText $tenantName)</strong></div>
      <div class="identity-cell"><span class="field-label">Generated</span><strong>$(ConvertTo-EncodedText $generatedDate)</strong><small>$(ConvertTo-EncodedText $generatedTime)</small></div>
      <div class="identity-cell"><span class="field-label">Report type</span><strong>Read-only</strong><small>RBAC analysis</small></div>
    </div>
  </section>

  <section class="map-section" aria-label="Administrator access paths">
    <div class="map-headings"><span>Administrator</span><span>Groups</span><span>Roles</span><span>Scopes</span><span>Permission families</span></div>
    <div class="map-layout">
      <div class="administrator-node"><div class="administrator-avatar"><img src="$iconUser" alt=""></div><strong>$(ConvertTo-EncodedText $userDisplayName)</strong><small>$(ConvertTo-EncodedText $userPrincipalName)</small><span class="user-type">User</span></div>
      <div class="path-stack">$mapRows</div>
    </div>
    <div class="map-legend"><span class="legend-key"><i></i>Confirmed access path</span><span class="legend-key unknown"><i></i>Not evaluated</span><span class="legend-note"><img src="$iconQuestion" alt="">Open any path to inspect its assignment and raw evidence.</span></div>
  </section>

  <section class="index-section" aria-labelledby="permission-index-title">
    <div class="index-title"><h2 id="permission-index-title">Permission index</h2><p>Allowed actions resolved from roles and scopes.</p><div class="filter-list" aria-label="Filter permissions by family">$filterControls</div></div>
    <div class="permission-list"><div class="permission-head"><span>Permission</span><span>Action</span><span>Status</span><span>Source</span></div><div class="permission-table">$permissionRows</div></div>
    <aside class="review-note"><div class="review-heading"><span class="review-icon"><img src="$iconLightbulb" alt=""></span><div><h2>Review note</h2><p>$reviewCount item$(if ($reviewCount -eq 1) { '' } else { 's' }) to inspect</p></div></div><ul>$warningHtml</ul><details class="method-detail"><summary>How evaluation works</summary><div class="method-content"><p>User &gt; Microsoft Entra group &gt; role assignment &gt; role definition &gt; exact allowed resource action. Unknown scope or nested-group cases remain NotEvaluated.</p><div class="graph-scopes">$graphScopeHtml</div></div></details></aside>
  </section>
</main>
<footer class="report-footer shell"><span>Open-source Intune RBAC explorer for auditors and administrators.</span><span>Generated locally by IntuneAccess $(ConvertTo-EncodedText (Get-IntuneAccessProperty $Access 'ToolVersion')). No tenant data was sent to the project author.</span></footer>
</body>
</html>
"@
}
