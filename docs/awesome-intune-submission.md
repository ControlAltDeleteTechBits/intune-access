# Awesome Intune submission draft

Prepared on 17 August 2026. Nothing in this document has been submitted.

## Awesome Pick route

The current Awesome Pick rules do not provide an entry form. A qualifying contribution must be posted by its creator in the Awesome Intune LinkedIn group during the current monthly cycle. The creator must belong to the group when posting and when selections are finalised.

Current cycle shown on the site: August 2026, closing 31 August 2026 at 23:59 Europe/Berlin.

## LinkedIn group post draft

I have built IntuneAccess, an open source, read only PowerShell module that joins Microsoft Intune administrative access, workload targeting, reported outcomes and change evidence.

Intune administrators often need to trace several separate objects to understand why a delegated administrator can manage a device or perform an action. IntuneAccess correlates the administrator, Microsoft Entra Admin Groups, Intune role assignments, role definitions, allowed actions, Scope (Groups) and Scope (Tags), then retains the evidence behind each conclusion.

The module returns structured PowerShell objects and generates a self contained Signal Atlas HTML explorer. It requests read permissions only, processes Graph data locally and uses `NotEvaluated` when the available evidence cannot prove a path.

Version 2.0.0 adds assignment impact across major Intune workloads, Device and User 360, deployment evidence, local snapshots, change comparison, recent Intune audit events and conservative policy setting conflict analysis. Seventy-seven automated unit tests pass with 81.44 per cent command coverage.

Repository: `https://github.com/ControlAltDeleteTechBits/intune-access`

PowerShell Gallery: `https://www.powershellgallery.com/packages/IntuneAccess`

Version 2.0.0 release: `[PUBLIC_GITHUB_2_0_RELEASE_URL]`

I would value testing feedback from Intune administrators who work with delegated RBAC, custom roles and scope tags.

## Awesome Intune directory form draft

Tool Name: IntuneAccess

Description:

`Read only PowerShell module that joins effective Intune RBAC, workload assignments, Device and User 360, deployment outcomes, local change snapshots and conservative policy conflict evidence in one self contained offline explorer.`

Authors: `[PUBLIC_AUTHOR_NAME]`

Author GitHub URL: `[OPTIONAL_AUTHOR_GITHUB_URL]`

Author LinkedIn URL: `[OPTIONAL_AUTHOR_LINKEDIN_URL]`

Tool URL: `https://github.com/ControlAltDeleteTechBits/intune-access`

Category: Reporting

Type: PowerShell Module

Confirmation required: the tool is Intune related, publicly accessible and the submitter has permission to submit it.

## Information still required

1. Public GitHub 2.0.0 release URL after live validation and publication.
2. Public author name.
3. Optional author GitHub, LinkedIn and X profile URLs.
4. Confirmation that the maintainer is a member of the Awesome Intune LinkedIn group.
5. Approval of the final directory description and LinkedIn post.

## Submission checks

1. Repository is public and includes the MIT licence.
2. README starts with the problem and contains installation, permissions, limitations, security and screenshots.
3. Release archive and SHA-256 checksum are attached to the GitHub release.
4. The public release notes retain all known limitations.
5. The LinkedIn post is published during the eligible monthly cycle.
6. The directory form is submitted only after the public Tool URL works.
