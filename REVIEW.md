# Review on 2026-11-16

Follow-up: the emoji alias and FormKit accessibility findings below have been
fixed. Existing history entries for aliases are merged with their usage counts.
The reset-button override was removed entirely at the user's request, restoring
core's default layout. The original findings below document the reviewed state.
The compatibility boundary remains a maintenance recommendation.
Follow-up validation: all 35 tests pass with 107 assertions at both 390px and
1280px. Component ESLint, template lint, Stylelint, and Prettier pass. Root
`bin/lint --fix` still encounters the documented ESLint/parser incompatibility.

Reviewed against the local Discourse v2026.7.2 checkout
(`3ab62a8397926ed934b667a5db06284c45b4c774`). No production code was changed.
The component does not need another complete rewrite. Three concrete issues and
an explicit compatibility boundary should be addressed before broader release.

**P2: Emoji aliases bypass pair deduplication.**

`javascripts/discourse/lib/status-pair.js:11-22` strips surrounding colons but
retains aliases and case. Current core treats `coffee` as an alias of
`hot_beverage`, while pair comparison and keys compare the original strings.
The default presets still contain `coffee`. Selecting the same emoji through
the picker can therefore create a visually identical pair that is accepted as
another preset or appears in frequent suggestions alongside its fixed preset.
Its usage count is also tracked separately.

Reproduced by replacing only the `:coffee:` fixture with `hot_beverage` in the
existing duplicate-preset acceptance test, using an intercepted browser response.
The unchanged uniqueness assertion fails. The source files and imported theme
were not modified. Resolve aliases centrally before comparison and storage,
preserving custom emoji behavior, and cover this case with regression tests.

**P2: The reset-button CSS affects sibling settings.**

`common/common.scss:216-231` selects every `.setting-controls__undo` below a
`.theme-settings` container whenever any preset editor is present. In the core
admin template that container wraps all three component settings. Overridden
`show_frequent_statuses` and `frequent_status_limit` settings consequently inherit
the preset editor's block display, clearing, and percentage-based indentation.
Scope this rule to the `status_presets` setting row. The copied label widths and
700px breakpoint remain coupled to the current admin layout.

**P2: Custom FormKit input omits error accessibility metadata.**

`javascripts/discourse/components/status-preset-editor.gjs:277-283` passes the
field ID, value, callback, and disabled state to `StatusPresetInput`, but does
not pass `field.error` or `field.describedBy`. The input in
`javascripts/discourse/components/status-preset-input.gjs:35-55` consequently has
neither `aria-invalid` nor `aria-describedby` when duplicate validation fails.
Observed in the running duplicate-pair integration test: the visible field error
reads "This emoji/text pair is already in the list.", while both attributes are
absent. Wire the FormKit error state and description IDs to the actual input.

**Compatibility boundary and maintenance.**

`about.json` declares no `minimum_discourse_version`. The component imports
`discourse/ui-kit/*` and relies on the current FormKit API, functional
`modifyClass`, and core status-modal internals. Older installations lacking these
APIs can fail during module loading. Choose and test the oldest supported core
version before declaring it in metadata. The current reusable CI workflow
defaults to core `latest`; it does not establish support for older releases.

The modal substitution, copied modal template, inherited `_itsatrap` field, user
save wrapper, and admin setting getters are identifiable maintenance seams. Their
current contracts match the checked-out core. Recheck both status entry points
and the admin editor after upgrades. An upstream status-modal outlet would allow
the modal substitution and template copy to be removed.

**Previous feedback.**

| Previous concern                                        | Current assessment                                                                                                                                                                                |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Component did not use the Discourse template            | Conventional component layout and official shared CI entry point are present. The pinned tooling differs from the newest skeleton; historical generation cannot be established from the files.    |
| One large stylesheet and widespread important overrides | One 232-line responsive stylesheet with distinct BEM blocks is reasonable here. Two documented `!important` declarations remain for focus and autofill. The reset selector above needs narrowing. |
| Glimmer component not in a `.gjs` file                  | Resolved: all five UI components use `.gjs`.                                                                                                                                                      |
| `pauseNotificationsValue` ignores user input            | Resolved: no such override remains. The checkbox binds `model.pauseNotifications`; the inherited core save action forwards it. Existing tests cover enabling notification pausing.                |
| Poor structure and readability                          | Responsibilities are separated into components, initializers, a history service, and pair utilities. No complete restructuring is justified.                                                      |
| Too many comments, in German                            | Resolved: six short English explanatory comments and two template-lint directives remain in production files.                                                                                     |
| Foundation modal right padding                          | Not reproduced: actual 390px and 1280px test viewports show 24px on both sides and no horizontal body overflow.                                                                                   |
| Missing tests                                           | 18 acceptance tests and 14 integration tests are present and pass. The alias reproduction identifies a missing regression case.                                                                   |
| Missing linting                                         | ESLint, template lint, Stylelint, and Prettier are configured and pass.                                                                                                                           |
| Missing CI                                              | Official reusable workflow is configured. A successful hosted GitHub run was not verified.                                                                                                        |
| Missing license                                         | MIT license is present in `LICENSE`.                                                                                                                                                              |

**Optional simplification.**

No clearly unused production imports, methods, or components were found. The
341-line custom preset editor and its admin adapters are the largest optional
complexity: removing them would mean accepting core's generic object editor and
losing the inline emoji preview and reordering experience. Keeping these features
justifies most of that code. Splitting the stylesheet alone would not resolve
any functional issue.

**Validation and limits.**

- All 32 existing tests passed, with 94 assertions and no browser exceptions.
- Tests also passed with the QUnit fixture adjusted to actual viewport widths of
  390 and 1280 pixels, allowing Foundation dialog geometry to be measured without
  the default scaled preview.
- The browser-only alias variant failed its uniqueness assertion as expected.
- The duplicate validation test confirmed the missing input ARIA attributes.
- Component ESLint, template lint, Stylelint, and Prettier passed. Lint processes
  used the installed Node 22 runtime; pnpm's standalone launcher reported its
  embedded Node 20 and required an engine-check override for that invocation.
- No fresh Wiblio visual matrix, Safari, RTL, older-core matrix, or hosted CI run
  was performed. The existing README's earlier checks are not substituted for
  fresh verification of those combinations.

Reference material: the official
[theme skeleton](https://github.com/discourse/discourse-theme-skeleton), its
[workflow entry point](https://github.com/discourse/discourse-theme-skeleton/blob/main/.github/workflows/discourse-theme.yml),
and the
[shared theme CI workflow](https://github.com/discourse/.github/blob/v1/.github/workflows/discourse-theme.yml).
