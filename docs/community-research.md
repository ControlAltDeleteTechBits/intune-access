# IntuneAccess community problem research

Research checked on 18 August 2026.

## Method and limits

This review used recent discussions from the `r/Intune` community and Microsoft documentation. The selected discussions are representative examples rather than a statistical sample. A community report can describe tenant configuration, client behaviour, delayed telemetry or a Microsoft service incident. It is not treated as proof of a product defect.

Each opportunity below states what IntuneAccess can establish from read only tenant evidence and what remains outside that evidence.

## Problem 1: Applications are assigned but missing from Company Portal

Observed reports:

1. Administrators reported available applications disappearing while assignments still appeared correct.
2. Similar reports affected Windows, iOS, Android and the web Company Portal at different times.
3. Some cases were service incidents. Other cases involved assignment intent, user targeting, primary user, filters or stale client state.

Representative discussions:

1. [Available applications missing for a subset of users](https://www.reddit.com/r/Intune/comments/1rcr3cp/company_portal_missing_apps/)
2. [Applications missing after a Company Portal update](https://www.reddit.com/r/Intune/comments/1vfd87s/no_apps_in_company_portal_after_update_to_11219260/)
3. [Company Portal service errors across platforms](https://www.reddit.com/r/Intune/comments/1u9w0yj/company_portal_issues/)

IntuneAccess can solve:

1. Prove whether the user and device are in the intended target path.
2. Show required, available and uninstall intent.
3. Resolve included groups, excluded groups, virtual groups and supported filters.
4. Check application platform, architecture, minimum operating system, requirements, dependencies and supersedence.
5. Compare the expected path with the latest reported application state.
6. State that configuration evidence is intact when the remaining cause is likely client side or service side.

IntuneAccess cannot prove a transient Company Portal or Intune service incident from assignments alone. It should label the unresolved boundary and include relevant timestamps.

## Problem 2: Autopilot succeeds partly but Enrollment Status Page times out

Observed reports:

1. Devices joined, enrolled and installed applications, but ESP still reached its timeout.
2. An application could install successfully without returning the state ESP expected.
3. Administrators had to correlate profile assignment, registry tracking, application state and local logs manually.

Representative discussions:

1. [Application installed while ESP waited for a useful state](https://www.reddit.com/r/Intune/comments/1um2l89/autopilot_timing_out_during_device_esp/)
2. [Hybrid Autopilot completed but ESP still failed](https://www.reddit.com/r/Intune/comments/1vmo14b/hybrid_autopilot_completes_adentraintune_installs/)
3. [Co-management policy provider timed out during ESP](https://www.reddit.com/r/Intune/comments/1v8y9uk/autopilot_comanagement_issue_im_stuck_on/)

IntuneAccess can solve:

1. Show the Autopilot and ESP profile assignment path.
2. Render beta Autopilot event phases, durations and failure details as a timeline.
3. Join tracked applications to their assignment, intent, dependencies and latest Intune state.
4. Identify a timeout, no result or inconsistent success evidence.
5. Direct the administrator to the specific local diagnostic source still required.

Microsoft documents that ESP troubleshooting can require MDM diagnostics, registry tracking and event logs. Graph evidence can shorten the investigation but cannot replace those local records. [Microsoft ESP troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/mem/intune/device-enrollment/understand-troubleshoot-esp).

## Problem 3: Compliance says failed or not applicable while the device appears healthy

Observed reports:

1. Antivirus, firewall, Secure Boot and custom compliance states sometimes disagreed with local or Defender observations.
2. Administrators reported old or delayed portal status after the underlying condition had recovered.
3. Shared devices produced confusing results involving enrolled user or default compliance rules.

Representative discussions:

1. [Antivirus reported noncompliant while Defender appeared healthy](https://www.reddit.com/r/Intune/comments/1vn4jen/windows_compliance_policy_failing_on_antivirus/)
2. [Custom compliance reported not applicable despite a compliant setting result](https://www.reddit.com/r/Intune/comments/1uwdo40/custom_compliance_policies_are_not_applicable/)
3. [Shared device default compliance confusion](https://www.reddit.com/r/Intune/comments/1udmswe/intune_compliance_shared_device_issues/)

IntuneAccess can solve:

1. Prove whether the compliance policy targeted the user or device.
2. Separate the custom policy, default compliance policy and individual setting results.
3. Compare last check in, policy evaluation and available security signal timestamps.
4. Highlight contradictory or stale evidence instead of choosing one result silently.
5. Explain documented default compliance checks in plain language.

IntuneAccess cannot declare the endpoint healthy when it has only tenant reporting data. A result such as `Reported conflict: endpoint confirmation required` is safer than overriding Intune.

## Problem 4: Policy conflicts are difficult to locate and explain

Observed reports:

1. Exclusions did not produce the expected result when group types or overlapping memberships were misunderstood.
2. Administrators struggled to locate another policy configuring the same setting.
3. Conflicts could cross Settings Catalog, endpoint security, security baselines and older configuration profiles.

Representative discussions:

1. [Conflict remained despite assignment exclusions](https://www.reddit.com/r/Intune/comments/1rq197j/device_configuration_policy_settings_conflicts/)
2. [Request to search every configuration profile for a setting](https://www.reddit.com/r/Intune/comments/1cdf9ej/search_trough_all_configuration_profiles/)
3. [Gradual rollout blocked by an overlapping setting](https://www.reddit.com/r/Intune/comments/1gsgxk8/conflicting_policies/)

IntuneAccess can solve:

1. Create a normalised setting index across supported policy families.
2. Show every source policy and configured value.
3. Resolve whether their assigned populations overlap.
4. Explain include and exclude evidence, including user and device targeting mismatches.
5. Separate a calculated overlap from a device reported conflict.

This capability is implemented locally in version 2.0.0. Different target groups, incomplete filters and unsupported setting contracts remain `NotEvaluated`.

## Problem 5: RBAC and scope tag behaviour is hard to prove

Observed reports:

1. Administrators saw actions greyed out even after activating elevated access.
2. Portal permission summaries did not make the full role, group and tag path obvious.
3. Default and country specific scope tags complicated diagnosis.

Representative discussion:

1. [Elevated RBAC permissions appeared not to take effect](https://www.reddit.com/r/Intune/comments/1ux0phv/rbac_no_longer_working/)

IntuneAccess can solve now:

1. Show Admin Groups, role assignments, roles, Scope Groups and Scope Tags.
2. Retain every granting assignment for cumulative permissions.
3. Highlight the difference between observed permissions and an action that remains unavailable in the portal.
4. Preserve `NotEvaluated` when Microsoft Entra roles, licensing or undocumented tenant state could affect the result.

This remains the core product strength in version 2.0.0.

## Problem 6: Duplicate and stale records disagree across Intune, Entra and Autopilot

Observed reports:

1. Re-enrolment produced several records with different names, identifiers or activity dates.
2. Administrators were unsure which record was safe to remove.
3. Intune and Entra activity timestamps could disagree.
4. Cleanup rules lacked the exception and evidence model some organisations wanted for long leave or shared devices.

Representative discussions:

1. [Duplicate and disappearing device records](https://www.reddit.com/r/Intune/comments/1um7kar/duplicate_devices_disappearing_devices/)
2. [Fragmented cleanup across Intune, Entra and Autopilot](https://www.reddit.com/r/Intune/comments/1s8hgu3/device_cleanup_in_intuneentraautopilot_is_a_mess/)
3. [Difficulty distinguishing stale devices from devices on long leave](https://www.reddit.com/r/Intune/comments/1tixvxt/how_do_you_handle_lost_disconnected_or_stale/)

IntuneAccess can solve safely:

1. Reconcile Intune managed device, Microsoft Entra device and Autopilot identities.
2. Compare serial number, Microsoft Entra device ID, Intune device ID, Autopilot record, primary user and activity timestamps.
3. Identify likely duplicate, orphaned, stale or mismatched records.
4. Explain why a record was flagged and provide evidence for manual review.
5. Track whether the discrepancy changes in a later snapshot.

IntuneAccess should not delete, disable or merge records. Read only reconciliation is useful without the risk of an incorrect cleanup action.

## Problem 7: Current dashboards do not answer historical or rollout questions

Observed reports:

1. Administrators created custom dashboards to obtain patch, operating system lifecycle and compliance history.
2. Historical reporting often required Azure Monitor, Log Analytics and KQL.
3. The built in update dashboard shows current posture but not historical trends or staged rollout intent.

Representative discussions:

1. [Community patch and operating system compliance dashboard](https://www.reddit.com/r/Intune/comments/1slzbwe/intune_patching_os_compliance_dashboard/)
2. [Custom historical reporting through Log Analytics](https://www.reddit.com/r/Intune/comments/1sftg9x/need_custom_intune_reports_beyond_what_the_intune/)

IntuneAccess can solve:

1. Save local snapshots without requiring an Azure workspace.
2. Compare device, compliance, application and update state between runs.
3. Correlate update assignments and rollout rings with current status.
4. Produce a portable trend and change report.

Microsoft states that the Security update status dashboard does not provide historical trends or model staged rollout logic. [Microsoft dashboard limitations](https://learn.microsoft.com/en-us/intune/device-security/security-update-status-dashboard).

## Problem 8: Administrators cannot tell whether a problem is configuration, telemetry or service health

This is the shared problem behind many discussions. The same symptom can be caused by several layers:

1. No assignment path.
2. An include or exclude rule.
3. A filter or requirement mismatch.
4. A client that has not checked in.
5. Delayed reporting.
6. Contradictory workload state.
7. A Microsoft service incident.

IntuneAccess can reduce the uncertainty by classifying evidence:

1. `Confirmed configuration path`.
2. `Expected from current assignments`.
3. `Excluded by observed evidence`.
4. `Reported error or conflict`.
5. `Stale or contradictory telemetry`.
6. `Client evidence required`.
7. `Service state not established`.

The final two states are important. The tool should say when it does not know rather than presenting a plausible guess as fact.

## Problem 9: MSPs need comparison across tenants

Observed reports:

1. MSP administrators asked for better multi tenant Intune management and reporting.
2. Configuration consistency, permissions and reporting were common requirements.

Representative discussion:

1. [Request for tools to manage Intune across several tenants](https://www.reddit.com/r/Intune/comments/1r0p1ia/anyone_know_some_good_tools_to_manage_intune/)

IntuneAccess opportunity after the core roadmap:

1. Generate one sanitised snapshot per tenant.
2. Compare role coverage, assignments, policy settings and hygiene findings offline.
3. Highlight differences from a selected reference tenant without changing either tenant.

This should follow the single tenant evidence model. It is not a priority for 1.2.0.

## Why administrators would use IntuneAccess

IntuneAccess turns scattered Intune records into a traceable answer:

`Who can change it > who should receive it > what Intune reported > where the evidence stops`

The practical reasons to use it are:

1. One investigation instead of moving between RBAC, groups, policy assignments, device pages, application reports and audit logs.
2. An explanation of relationships rather than a plain inventory export.
3. Clear separation between confirmed evidence, calculated expectation and unavailable data.
4. A local, read only report with no hosted tenant data, telemetry or write permission.
5. A guided PowerShell command that signs in, collects evidence, generates HTML and opens the report.
6. Useful core analysis without requiring Security Copilot capacity.
7. Self contained evidence that can be reviewed offline or sanitised for a support case.
8. Historical comparison without requiring the organisation to deploy Log Analytics for the basic snapshot workflow.
9. A joined administrator, targeting and outcome view that the current Intune portal does not present as one durable report.

## Recommended community led additions

1. Version 2.1.0 adds Intune, Microsoft Entra ID and Autopilot device identity reconciliation, evidence age and hygiene findings.
2. Version 2.2.0 adds the device assignment explainer across groups, exclusions, filters, intent and reported outcome.
3. Version 2.3.0 adds an optional Autopilot and Enrollment Status Page evidence timeline.
4. Version 2.4.0 adds application requirements, dependencies, supersedence, detected software and supported error evidence.
5. Version 2.5.0 adds telemetry staleness, update history and compliance investigation.
6. Version 3.0.0 adds prioritised findings, historical trends, a sanitised support bundle and cross-device investigation.
7. Expand normalised setting coverage only where Microsoft Graph exposes a dependable read contract.
8. Keep offline cross-tenant snapshot comparison as a deferred candidate until the single-tenant device model is validated at scale.
