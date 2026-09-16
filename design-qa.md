# IntuneAccess Signal Atlas design QA

## Comparison target

Source reference: the approved Signal Atlas mock-up, retained privately outside the repository.

Implementation screenshot: `screenshots/IntuneAccess-signal-atlas-full.png`.

Combined comparison: `screenshots/IntuneAccess-signal-atlas-comparison.png`.

State: default read-only report with all permission families visible and evidence details closed.

## Viewport and normalisation

1. Source image: 1487 × 1058 pixels.
2. Browser CSS viewport: 1280 × 720 pixels at device scale factor 1.
3. Browser viewport capture: 1265 × 712 pixels after browser scrollbar and capture bounds.
4. Stitched implementation: 1265 × 1117 pixels, composed from two browser-rendered viewport captures with a measured 405 pixel scroll offset.
5. The comparison image scales both full report images to an equal display height. No density mismatch was used to file findings.

## Full-view comparison evidence

The combined image shows the source and browser-rendered implementation together. The implementation preserves the selected structure: slim report header, large access-map title, administrator identity strip, left-to-right access paths, yellow confirmed connectors, grey dashed unknown connectors, permission-family index, evidence table and review note.

## Focused comparison evidence

The following browser captures were reviewed at native capture size:

1. `screenshots\IntuneAccess-signal-atlas-top.png` for the header, identity strip, access-map columns, card alignment, icons and connectors.
2. `screenshots\IntuneAccess-signal-atlas-index.png` for the permission filters, table typography, status indicators, review note and footer.
3. `screenshots\IntuneAccess-signal-atlas-mobile.png` for the 390 pixel responsive layout.

Separate crop files were not needed because the two native viewport captures make the important typography, controls and icons readable.

## Required fidelity surfaces

### Fonts and typography

Space Grotesk is embedded for headings and interface text. IBM Plex Mono is embedded for field labels, identifiers and technical metadata. Weight, hierarchy, wrapping and compact labels follow the source. The fonts are bundled locally and do not create a remote runtime dependency.

### Spacing and layout rhythm

The main horizontal composition, column order, card rhythm and permission-index split match the source. Desktop paths retain even vertical spacing. The mobile view intentionally becomes a vertical evidence sequence and has no horizontal page overflow.

### Colours and visual tokens

The implementation uses an off-white paper background, black type, light grey rules, yellow confirmed states, grey unevaluated states and restrained blue focus outlines. Contrast remains clear across body text, labels and states.

### Image quality and asset fidelity

All visible interface icons come from the Phosphor icon library and are embedded as self-contained image assets. They render sharply at the target sizes. No remote image or icon dependency is used.

### Copy and content

The report uses actual administrator, tenant, assignment, scope, permission and warning data. The review note preserves calculation limits rather than replacing them with design-only placeholder copy.

## Findings

No actionable P0, P1 or P2 mismatch remains.

## Comparison history

### Pass 1

1. P2: The first CSS-only permission filter selector could not reach the permission table from its original container. The selector now scopes through the index section, and the Mobile Apps filter was verified to hide four unrelated rows while retaining the matching row.
2. P2: The desktop metadata strip overflowed at the browser's 1280 pixel viewport. The tenant pill now collapses at that width, connector gaps tighten and the persistent read-only metadata remains visible.
3. P2: The initial 390 pixel responsive view had a 666 pixel document width because of the desktop permission-table minimum width. The mobile table now uses a two-column row layout. The verified document width is 375 pixels inside a 390 pixel viewport.

### Pass 2

1. The access-path evidence disclosure opens and closes correctly.
2. Permission-family filtering works without JavaScript.
3. The default desktop report, permission index and responsive layout render without browser console errors.
4. No P0, P1 or P2 issue remains in the combined post-fix comparison.

## Follow-up polish

P3: Numbered stage badges and the branched elbow connector from the source mock are omitted. The implementation favours repeatable rows that can handle an unknown number of live assignments without overlap.

P3: The All filter is an intentional addition to support real report use. It slightly changes the permission-family list from the mock.

## Implementation checklist

1. Selected visual resolved from displayed option 3.
2. Offline fonts and icons bundled with licence files.
3. Report generator updated with data-driven access paths and permission rows.
4. Evidence disclosures and permission filters tested.
5. Desktop and mobile layouts checked.
6. Browser console checked with no errors.
7. Unit test suite passed: 26 tests.
8. PowerShell Script Analyzer returned no findings.

final result: passed
