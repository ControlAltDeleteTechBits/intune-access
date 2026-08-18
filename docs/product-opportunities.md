# IntuneAccess product opportunities

Research checked on 18 August 2026.

This document records recurring Intune administration problems that IntuneAccess could address without becoming a configuration or remediation product. A gap does not always mean that Microsoft Intune has no related feature. In several cases the available data is split across portal pages, limited to one workload, dependent on additional licensing or unavailable as a durable evidence chain.

## Current Intune position

The current Intune admin centre includes Explorer, Security Copilot agents, operational reports and the Security update status dashboard.

1. Explorer can query supported Intune views using natural language, including apps, compliance, device configuration, updates, audit logs, RBAC, users, groups and Autopilot. It requires Security Copilot and matches requests to query views built into Intune.
2. Intune agents cover change review, device offboarding, policy configuration and vulnerability remediation. They require Security Copilot capacity and are designed to recommend or perform actions with administrator oversight.
3. The Security update status dashboard provides a fleet summary. Microsoft documents that it does not provide historical trends, model staged rollout logic or perform root cause analysis.
4. Microsoft Defender exposes effective security settings for a device, but this is a security focused Defender experience rather than a joined result for every Intune workload.

IntuneAccess should not recreate these portal pages. Its opportunity is a free, local, read only and shareable evidence report that explains relationships across them.

## Priority 1: Resultant Intune state

Recurring request: administrators want an Intune equivalent of `gpresult` that shows which policies and settings reached a device, the source of each setting and why another setting did not apply.

IntuneAccess opportunity:

1. Search a device, user or setting once across supported policy families.
2. Show the source policy, assignment path, filters, exclusions, scope tags and reporting state.
3. Separate configured intent, expected applicability, reported outcome and effective value.
4. Never claim an effective device value when only tenant configuration data is available.

This is the strongest long term opportunity because it joins the planned 1.2.0 assignment explorer, 1.3.0 outcome evidence and 2.0.0 overlap analysis.

Evidence:

1. [Community request for an Intune GPResult equivalent and cross policy setting search](https://www.reddit.com/r/Intune/comments/1ev72cs/migrating_from_adgposccm_most_missing_intune/)
2. [Microsoft community GPResult like sample](https://techcommunity.microsoft.com/blog/coreinfrastructureandsecurityblog/gpresult-like-tool-for-intune/4437008)
3. [Microsoft Defender effective settings](https://learn.microsoft.com/en-us/defender-xdr/entity-page-device)

## Priority 2: Assignment outcome explainer

Recurring request: administrators can see an assignment but still cannot explain why a user or device was included, excluded, not applicable or absent from Company Portal.

IntuneAccess opportunity:

1. Resolve direct and transitive group membership.
2. Show included groups, excluded groups, virtual groups and assignment intent.
3. Evaluate supported assignment filter properties against the selected device evidence.
4. Explain filter precedence and preserve Intune's reported evaluation when it is available.
5. Highlight missing evidence, evaluation delay and known unsupported combinations.
6. Show application requirements, architecture, minimum operating system, dependencies and supersedence beside the targeting path.

Microsoft documents that filter results can take up to 30 minutes to appear and that some results have workload specific limitations. Community reports continue to show confusion around apps disappearing from Company Portal, leading whitespace in filter rules and `Not applicable` results.

Evidence:

1. [Microsoft assignment filter reports and troubleshooting](https://learn.microsoft.com/en-us/intune/fundamentals/filters/troubleshoot)
2. [Community example of an assignment filter causing an app to disappear](https://www.reddit.com/r/Intune/comments/1skeef7/ios_app_assignments_and_filters/)
3. [Community request to explain an app reported as not applicable](https://www.reddit.com/r/Intune/comments/1f9mrv0/app_deployment_and_not_applicable_status/)

## Priority 3: Change impact and durable history

Recurring request: administrators want to know exactly what changed, who changed it and which users or devices were affected. Audit events show activity, but a configuration snapshot is needed to calculate structural and targeting differences reliably.

IntuneAccess opportunity:

1. Compare two local snapshots.
2. Show old and new policy settings, assignments, filters, roles and scope tags.
3. Correlate the responsible Intune audit event when the resource IDs and time window match.
4. Calculate the potentially affected population without making a tenant change.
5. Produce a redacted change report for peer review or a support case.

Microsoft Graph can return two years of Intune audit events, including actors, targets and modified properties. Local snapshots add the relationship and impact view that audit events alone cannot always provide.

Evidence:

1. [Microsoft Intune audit logs](https://learn.microsoft.com/en-us/intune/governance/monitor-audit-logs)
2. [Microsoft Graph audit event resource](https://learn.microsoft.com/en-us/graph/api/resources/intune-auditing-auditevent?view=graph-rest-1.0)
3. [Community request for setting level change management and rollback evidence](https://www.reddit.com/r/Intune/comments/13e7g4l/intune_change_management/)

## Priority 4: Application deployment explainer

Recurring request: Intune reports installed, failed, pending or not applicable, but administrators still need to inspect assignments, requirements, detection rules and client logs separately.

IntuneAccess opportunity:

1. Join the application, assignment intent, target path, requirements, detection configuration, dependencies and supersedence.
2. Translate documented result and return codes into clear descriptions.
3. Flag common configuration risks, such as user versus device targeting, incompatible architecture and a detection script that cannot produce the documented success result.
4. Distinguish a confirmed Intune error from a likely configuration risk.
5. Link to the exact portal and Microsoft troubleshooting location for evidence that remains client side.

Graph data cannot replace Intune Management Extension logs. The report must say when client diagnostics are required.

Evidence:

1. [Microsoft Win32 application troubleshooting](https://learn.microsoft.com/en-ie/intune/intune-service/apps/apps-win32-troubleshoot)
2. [Microsoft Win32 application detection behaviour](https://learn.microsoft.com/en-us/intune/app-management/deployment/add-win32)
3. [Community example of an installation completing while ESP waits for status](https://www.reddit.com/r/Intune/comments/1um2l89/autopilot_timing_out_during_device_esp/)

## Priority 5: Autopilot evidence timeline

Recurring request: administrators want a single timeline showing the Autopilot profile, Enrollment Status Page phases, tracked applications, policies, duration and failure evidence.

IntuneAccess opportunity:

1. Use the documented beta Autopilot event and policy status detail resources as optional enrichment.
2. Display preparation, device setup and account setup as a timeline.
3. Join the Autopilot profile and Enrollment Status Page profile to their assignments.
4. Identify which tracked workload reported failure, timeout or no result.
5. Mark deeper local diagnosis as unavailable unless the user supplies device diagnostics in a future, separately designed feature.

Evidence:

1. [Microsoft Graph Autopilot event resource](https://learn.microsoft.com/en-us/graph/api/resources/intune-troubleshooting-devicemanagementautopilotevent?view=graph-rest-beta)
2. [Microsoft Enrollment Status Page troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/mem/intune/device-enrollment/understand-troubleshoot-esp)
3. [Community report that the enrollment failure report lacked a useful breadcrumb trail](https://www.reddit.com/r/Intune/comments/xy5n71/is_the_enrollment_failures_reporting_section/)

## Priority 6: Update rollout and history

Recurring request: administrators want to understand whether a device is behind because it was not targeted, its rollout ring deferred the update, it stopped reporting or the update failed.

IntuneAccess opportunity:

1. Join update ring, feature update, quality update and driver policy assignments to device status.
2. Model the intended rollout sequence without treating deployment timing as failure.
3. Use local snapshots to show historical movement between current, exposed, critical and stale states.
4. Identify devices that are behind and also outside the expected policy targeting path.

This complements the dashboard visible in the supplied screenshot. Microsoft states that the dashboard is a snapshot, does not model staged rollout logic and does not provide historical trend tracking.

Evidence:

1. [Microsoft Security update status dashboard and limitations](https://learn.microsoft.com/en-us/intune/device-security/security-update-status-dashboard)
2. [Community request for clearer Windows update compliance reporting](https://www.reddit.com/r/Intune/comments/1gexwdz/windows_update_compliance_reporting/)

## Priority 7: Policy search, overlap and conflict map

Recurring request: administrators need to find every policy that configures a setting and understand whether overlapping targets receive different values.

IntuneAccess opportunity:

1. Build a normalised setting index across supported policy families.
2. Search by setting name, setting identifier, policy, platform or target.
3. Compare configured values only where the definitions can be mapped safely.
4. Overlay target populations so a duplicate setting is not labelled a practical conflict when the populations do not overlap.
5. Show the reported device result separately from calculated overlap.

This is the planned version 2.0.0 feature and should follow the assignment and outcome collectors because target overlap is essential evidence.

## Priority 8: Share safe support bundle

Recurring request: administrators need to share enough evidence with colleagues, vendors or Microsoft support without disclosing unnecessary tenant data.

IntuneAccess opportunity:

1. Redact tenant names, user principal names, serial numbers and object IDs consistently.
2. Preserve relationships through stable replacement identifiers.
3. Include selected findings, source timestamps, missing permissions and collection warnings.
4. Export a self contained HTML report and structured JSON evidence.

## Features not to prioritise

1. A generic home dashboard. Intune already provides status cards, reports and update posture summaries.
2. A natural language query clone. Explorer already provides this when Security Copilot is enabled.
3. Automated device offboarding or policy creation. Microsoft agents now cover these areas and they conflict with the product's read only identity.
4. General tenant backup, import and restore. Established community tools already cover this, and write operations would change the security model.
5. A plain inventory export. Microsoft's Intune tenant documentation project already covers broad documentation. IntuneAccess should explain relationships and impact instead.

## Recommended fit with the agreed roadmap

1. Version 1.2.0 delivers the assignment outcome explainer.
2. Version 1.3.0 adds Device and User 360, application deployment evidence and an optional Autopilot timeline.
3. Version 1.4.0 adds durable history, change impact, update movement and share safe reports.
4. Version 2.0.0 delivers resultant state search plus policy overlap and conflict analysis.
