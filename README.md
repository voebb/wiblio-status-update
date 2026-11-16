# Wiblio status update

A standalone Discourse theme component with configurable emoji/text status
shortcuts and personal frequently used statuses. Supports Foundation and Wiblio
without depending on Wiblio or any plugin.

## Installation and settings

Import the component archive in **Admin > Appearance > Themes & components**, or
run `discourse_theme watch .` in this directory. Attach the component to each theme
that should use it. Enable Discourse's `enable_user_status` site setting.

Use one installed copy and attach it to all desired parent themes. For updates,
update the existing component or select that installation in `discourse_theme
watch`. Importing the archive again creates a separate installation, which can
cause duplicate initializer registration and leave the other copy's settings
with the standard editor.

Configure `status_presets` directly in the component settings. The inline editor
is on the component's main settings page at `/admin/customize/themes/<id>`.
The component does not add a separate editor page or a redirect.
The editor
shows the configured pairs above an emoji picker and status text input. Plus (or
Enter) adds a pair to the preview. Click a pair to edit it, confirm with the check
button, or remove it with its cross. Drag pairs to reorder them, or select one and use the earlier/later buttons on
touch devices.
The setting's normal save checkmark persists the preview; Cancel restores the
saved list. No separate preset editing page is needed.

The stored format remains an ordered array of objects with an `emoji` shortcode
and a `label` of up to 100 characters. The emoji picker supports custom emojis.
Invalid or duplicate pairs are not added by the inline editor. Invalid entries
from other editors are omitted from the user-facing shortcuts. The sample labels
can be edited to match the community's language. Interface translations are
included for English and German.

Selecting a shortcut fills the existing emoji/text picker. Users can still edit
both fields and create any custom status. Nothing is persisted until Save is
pressed. Discourse continues to handle expiration, notification pausing, status
deletion, and server validation. In account preferences, the page itself must
also be saved, as in core.

## Frequently used statuses

`show_frequent_statuses` enables recording and displaying personal suggestions;
`frequent_status_limit` controls the number shown (default 5, maximum 10).
Successful saves through the status dialog count, including custom statuses.
Cancelled or failed saves and deleted statuses do not increment counts. Account
preferences count only after the account save succeeds; saving unrelated account
fields again does not count the same selection twice.

Emoji aliases share a canonical name for comparisons and history; existing alias
entries are combined without losing their usage counts or most recent use.
Pairs are ranked by usage count, then most recent use. Pairs already in the fixed
shortcuts are omitted from the frequent section. History begins when the component
is installed; Discourse does not provide earlier usage history.

History is stored in this browser's local storage, separately for each user ID and
site origin, keeping the 50 most recently used pairs per account. It is not synced
between browsers or devices and disappears when browser storage is cleared. “Clear history” removes
the current account's local history. Disabling the feature stops recording and
displaying suggestions but keeps existing history. If browser storage is denied
or full, normal status editing and fixed shortcuts continue to work.

## Integration and maintenance

Core's status modal currently has no plugin outlet for shortcuts. The component
therefore uses a narrowly scoped `modifyClass` extension of `service:modal` to
substitute only `UserStatusModal`. Its modal subclasses the core modal and reuses
its state, actions, emoji picker, time picker, and model callbacks. The template
adds suggestions while retaining the core controls. Other modals pass through.

A second extension of `model:user.save` commits staged account-preference history
only after a successful save containing the matching status for the current user.
It does not change the request or the model's return value.

These depend on core's modal template, callback contract, and user save API. Check
both status entry points after Discourse updates. When core gains a suitable
outlet, migrate the suggestions there and remove the modal substitution.

The preset editor narrowly extends `component:theme-setting-editor`. It replaces
the edit-page button and resolved input only for this component's `status_presets`
setting, identified by the model's theme ID and its registered settings object.
Other components and settings retain the core editor. The schema and settings
endpoint remain unchanged, including server validation and admin authorization.
The composer uses a FormKit custom control with the same emoji picker and default
emoji as personal status editing. It deliberately does not autofocus on page load.
The dialog reuses this combined emoji/text control and focuses it on opening.
FormKit's max format fills the available composer width. The object editor has
its own setting type class so core's overridden-string background does not apply.
Focus belongs to the combined wrapper, including when the emoji button is focused.
The personal-history checkbox uses a scoped control to separate its label from
the retention description while retaining standard setting save/cancel behavior.
The admin component lookup is optional so public pages do not need the admin bundle.
The inline editor is available when this component is attached to the active theme;
the core object editor remains the fallback otherwise.

Styles live in `common/common.scss`, use Discourse's runtime CSS variables and
button styles, and are limited to the component's own BEM classes. Buttons wrap
to fit narrow viewports and expose the selected state through `aria-pressed`.

## Development

Install dependencies with `pnpm install`, then run `pnpm lint`. From the Discourse
root, after importing the component, run:

```sh
bin/qunit --qunit-path /theme-qunit --theme-name wiblio-status-update
```

Verify preset selection, custom editing, cancellation, error handling, expiration,
notification pausing, deletion, and account preference saves. Check Foundation and
Wiblio on desktop and mobile in both light and dark palettes.

## Validation on 2026-11-16

- All 35 tests passed: 20 status acceptance tests and 15
  inline preset editor integration tests, including alias deduplication, history
  count merging, skin tones, and accessible validation errors (107 assertions).
- Component ESLint, template lint, Stylelint, and Prettier passed.
- The shared admin/dialog input passed current browser checks on Foundation and
  Wiblio in light/dark modes at 390 and 1280 pixels: available width, wrapper focus,
  transparent text field background, simulated autofill masking, and icon spacing.
  The personal-history label and separate retention description were also checked.
- The inline preset editor passed live checks on Foundation and Wiblio in
  light/dark palettes at 390 and 1280 pixels. Native Enter, emoji selection,
  drag-and-drop, save, and reload preserved the expected list and order. Existing
  presets were restored after the temporary save check.
- Live browser checks passed on Foundation and Wiblio, each in light/dark palettes
  at 390 and 1280 pixels. Checked configured and personal suggestions, long-label
  wrapping, selected state, editing, saving, reopening, and browser errors.
  Live checks intercepted status writes so the test account's stored status was
  not changed.
- Root `bin/lint --fix` was attempted. Its ESLint 10.6.0/parser combination fails
  with `scopeManager.addGlobals is not a function`; the component's pinned
  ESLint 9.39.2 toolchain passed instead.

## Files

All component files are under `themes/wiblio-status-update/`:

| Files                                                               | Purpose                                                    |
| ------------------------------------------------------------------- | ---------------------------------------------------------- |
| `about.json`                                                        | Standalone component metadata                              |
| `settings.yml`                                                      | Ordered emoji/text presets and frequent-status options     |
| `locales/en.yml`, `locales/de.yml`                                  | Interface and setting translations                         |
| `common/common.scss`                                                | Scoped, responsive styles                                  |
| `javascripts/discourse/components/modal/status-update.gjs`          | Extended core status dialog                                |
| `javascripts/discourse/components/status-suggestions.gjs`           | Preset and frequent-status buttons                         |
| `javascripts/discourse/components/status-preset-editor.gjs`         | Inline preset preview, editing, and reordering             |
| `javascripts/discourse/components/status-preset-input.gjs`          | FormKit combined emoji/text control                        |
| `javascripts/discourse/components/status-history-setting.gjs`       | Personal history checkbox label                            |
| `javascripts/discourse/lib/status-pair.js`                          | Pair validation and comparison                             |
| `javascripts/discourse/services/wiblio-status-history.js`           | Per-account browser history                                |
| `javascripts/discourse/pre-initializers/status-update.js`           | Modal substitution and successful preference-save tracking |
| `javascripts/discourse/pre-initializers/status-preset-editor.js`    | Scoped integration with component settings                 |
| `test/acceptance/status-update-test.js`                             | Status workflow regression tests                           |
| `test/integration/status-preset-editor-test.gjs`                    | Preset editing, saving, rollback, and sorting tests        |
| `package.json`, `pnpm-lock.yaml`, `Gemfile`                         | Pinned development tools                                   |
| `eslint.config.mjs`, `.template-lintrc.cjs`, `stylelint.config.mjs` | JavaScript, template, and CSS lint configuration           |
| `.prettierrc.cjs`, `.prettierignore`                                | Formatting configuration                                   |
| `.github/workflows/discourse-theme.yml`                             | Discourse theme CI workflow                                |
| `.gitignore`                                                        | Local tooling and credential exclusions                    |
| `LICENSE`, `README.md`                                              | License, setup, architecture, and validation documentation |
