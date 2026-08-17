# Awesome Intune submission draft

Prepared on 17 August 2026. Nothing in this document has been submitted.

## Awesome Pick route

The current Awesome Pick rules do not provide an entry form. A qualifying contribution must be posted by its creator in the Awesome Intune LinkedIn group during the current monthly cycle. The creator must belong to the group when posting and when selections are finalised.

Current cycle shown on the site: August 2026, closing 31 August 2026 at 23:59 Europe/Berlin.

## LinkedIn group post draft

I have released IntuneAccess, an open source, read only PowerShell module for explaining effective Microsoft Intune RBAC access.

Intune administrators often need to trace several separate objects to understand why a delegated administrator can manage a device or perform an action. IntuneAccess correlates the administrator, Microsoft Entra Admin Groups, Intune role assignments, role definitions, allowed actions, Scope (Groups) and Scope (Tags), then retains the evidence behind each conclusion.

The module returns structured PowerShell objects and can also generate a self contained HTML access map. It requests read permissions only, processes Graph data locally and uses `NotEvaluated` when the available evidence cannot prove a path.

Version 1.0.0 includes administrator access analysis, duplicate permission evidence, scope tag auditing, managed-device access explanation and 45 automated unit tests.

Repository: `[PUBLIC_GITHUB_REPOSITORY_URL]`

Release: `[PUBLIC_GITHUB_RELEASE_URL]`

I would value testing feedback from Intune administrators who work with delegated RBAC, custom roles and scope tags.

## Awesome Intune directory form draft

Tool Name: IntuneAccess

Description:

`Read only PowerShell module that explains effective Microsoft Intune RBAC access by correlating administrators, Microsoft Entra groups, role assignments, role definitions, allowed actions, Scope (Groups) and Scope (Tags). It returns structured evidence and can generate a self contained offline HTML access map.`

Authors: `[PUBLIC_AUTHOR_NAME]`

Author GitHub URL: `[OPTIONAL_AUTHOR_GITHUB_URL]`

Author LinkedIn URL: `[OPTIONAL_AUTHOR_LINKEDIN_URL]`

Tool URL: `[PUBLIC_GITHUB_REPOSITORY_URL]`

Category: Reporting

Type: PowerShell Module

Confirmation required: the tool is Intune related, publicly accessible and the submitter has permission to submit it.

## Information still required

1. Public GitHub repository URL.
2. Public GitHub release URL.
3. Public author name.
4. Optional author GitHub, LinkedIn and X profile URLs.
5. Confirmation that the maintainer is a member of the Awesome Intune LinkedIn group.
6. Approval of the final directory description and LinkedIn post.

## Submission checks

1. Repository is public and includes the MIT licence.
2. README starts with the problem and contains installation, permissions, limitations, security and screenshots.
3. Release archive and SHA-256 checksum are attached to the GitHub release.
4. The public release notes retain all known limitations.
5. The LinkedIn post is published during the eligible monthly cycle.
6. The directory form is submitted only after the public Tool URL works.
