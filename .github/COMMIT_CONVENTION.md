# Commit Message Convention

Format used across this codebase. Mixes
[Conventional Commits](https://www.conventionalcommits.org/) with
[Gitmoji](https://gitmoji.dev/) and a few in-house tweaks (full-word, uppercase
type tags; mandatory body for non-trivial commits; structured footers).

This document doubles as a **prompt for AI assistants** — see the
[AI Prompt](#ai-prompt) section at the bottom: paste it before the diff/changes
description and the assistant will produce a commit message in the right shape.

## Anatomy

```text
[TYPE][TASK_ID?]: <gitmoji> <subject in sentence case, no abbreviations>

<one-paragraph description of what changed and why>

- <bullet describing a modified/created/removed/moved file or area>
- <another bullet>

<optional footers>
```

### Header Line — `[TYPE][TASK_ID?]: <gitmoji> <subject>`

- **`TYPE`** is **uppercase, full word, never abbreviated** (e.g. `FEATURE`,
  not `feat`). Append `!` when the change is breaking: `[REFACTOR!]`.
- **`TASK_ID`** is optional. When present it is the second bracket pair and
  references the task tracker id: `[FEATURE][4287]`.
- **`<gitmoji>`** is a single emoji that matches the change (see table below).
- **`<subject>`** is in sentence case (only the first word capitalized, plus
  proper nouns/acronyms), no trailing period, no abbreviations.
- Soft limit: ~72 characters total. If you can't fit it, you're packing
  multiple concerns — split the commit.

### Body

- One blank line after the header.
- A short paragraph (1–3 sentences) explaining **what** changed and **why**.
  The "what" is also visible in the diff; the body should add the "why" that
  the diff cannot show.
- For trivial commits (typo fix, version bump) the body can be omitted.

### Bullet List

- One blank line after the description.
- Use bullets for the concrete things modified/created/removed/moved.
- Keep each bullet a single line when possible. Wrap at ~80 chars.
- Group bullets by area when the commit touches multiple layers (use a
  single-line heading followed by its bullets — see the example below).

### Footers

- Blank line, then any number of footers.
- Common footers:
  - `Task #<id>: <task description>` — link to a task tracker entry.
  - `BREAKING CHANGE: <description>` — required when the type carries `!`.
  - `Refs: <commit-hash>` — when the commit follows up another.
- **Strict Rule:** Never use `Co-authored-by` tags. They are explicitly forbidden in this repository.

## Type Vocabulary

Use the full word in uppercase. Append `!` for breaking changes.

| Type       | When to use                                                   | Default Gitmoji |
|------------|---------------------------------------------------------------|-----------------|
| `FEATURE`  | New capability visible to users / consumers                   | ✨               |
| `BUGFIX`   | Bug fix that does not change public API                       | 🐛              |
| `REFACTOR` | Internal restructure, no behavior change                      | ♻️              |
| `PERF`     | Performance improvement, no behavior change                   | ⚡️              |
| `STYLE`    | Formatting / lint-only changes                                | 🎨              |
| `TEST`     | Adding or fixing tests                                        | ✅               |
| `DOCS`     | Documentation only                                            | 📝              |
| `CHORE`    | Build, dependencies tooling, configs that don't ship to users | 🔧              |
| `BUILD`    | Build system / packaging changes                              | 📦              |
| `CI`       | CI/CD pipeline changes                                        | 👷              |
| `REVERT`   | Reverting a previous commit                                   | ⏪               |

Pick a different Gitmoji than the table default when it conveys the change
better. Cheat-sheet of frequently used ones:

| Gitmoji | Meaning                            |
|---------|------------------------------------|
| 🎉      | Initial commit / project bootstrap |
| 🚀      | Deploy / ship                      |
| 🏗️     | Architectural change               |
| 🔥      | Remove code or files               |
| 🚑      | Critical hot fix                   |
| 🔒      | Security fix                       |
| ⬆️ / ⬇️ | Upgrade / downgrade dependency     |
| 🔖      | Release / version tag              |
| 🚧      | Work in progress                   |
| 🩹      | Simple fix for a noncritical issue |
| 💄      | UI / cosmetic change               |
| 🧪      | Add a failing test                 |
| 🗑️     | Deprecate code                     |

Full list: <https://gitmoji.dev/>.

## Examples

### Chore — Minimal

```text
[CHORE]: 🔖 Update package version to 2.3.0+45

This commit updates the version to reflect the new release updates.

- The `version` field in `pubspec.yaml` was bumped to `2.3.0+45`
- `CHANGELOG.md` was appended with a 2.3.0+45 section
```

### Refactor — Breaking Change

```text
[REFACTOR!]: ♻️ Replace legacy ChangeNotifier Command with Cubit Command

The legacy `Command` implementation in `legacy_command.dart` was highly
verbose and relied on `ChangeNotifier`. Migrating the settings feature to
the new `Cubit`-based `Command` standardizes our state management and
removes boilerplate across the presentation layer.

lib/src/presentation/settings/:
- Refactored `settings_bloc.dart` to consume the new Cubit `Command`
- Removed `ChangeNotifierProvider` from `settings_view.dart`
- Updated `settings_viewmodel.dart` to handle `CommandCompleted` state

BREAKING CHANGE: The legacy settings view model now expects a
Cubit-based command. Any widget observing the old `ChangeNotifier`
will break.
```

### Feature — with Task Id

```text
[FEATURE][214]: ✨ Implement CSV export for reports

Adds a streaming exporter that writes generated reports to CSV on
disk. This lets users archive reports and open them in spreadsheet
tools without an internet connection.

lib/src/data/:
- Created `report_csv_writer.dart` for streaming CSV serialization
- Added `export_job_manager.dart` to coordinate the export queue

lib/src/presentation/reports/:
- Wired a "Export as CSV" action into `reports_view.dart`

Task #214: Add offline export support for reports
```

## Process for AI Assistants

When asked to write a commit message, follow these steps in order. Do **not**
skip a step — each one prevents a common mistake.

1. **Inspect the diff.** Read the full set of staged changes (or the
   description the user provided). Note files added, modified, removed,
   moved/renamed; group them by layer (`lib/`, `android/`, `ios/`, etc.). 
   Skim docs/config files for clues about intent.
2. **Pick the type and breakingness.** Choose a single `TYPE` from the table.
   If the commit touches multiple concerns (e.g. a feature + an unrelated
   refactor), say so — the right answer is usually "split the commit", not
   stretch the type. Mark `!` only when public API or migrations break.
3. **Choose a Gitmoji.** Default from the type table; override only when a
   more specific Gitmoji conveys the change better (🎉 for bootstrap, 🚧 for
   WIP, 🔥 for deletion, etc.).
4. **Write the subject.** Sentence case, no abbreviations, no period, ≤ 72
   chars including the prefix and Gitmoji. The verb should describe **what
   the commit does** (`Implement`, `Replace`, `Fix`, `Document`), not what
   the contributor did.
5. **Write the description.** One paragraph. Cover *why* the diff cannot
   show. Skip it only for trivial commits.
6. **List the changes.** One bullet per concrete file/area. Group by layer
   with a single-line heading when more than ~5 bullets. Prefer past-tense
   verbs (`Created`, `Removed`, `Replaced`, `Moved … to …`).
7. **Add footers if needed.** `Task #<id>` for linked work, `BREAKING CHANGE`
   when the type carries `!`, or `Refs: <hash>`. Do **not** add `Co-authored-by` tags.
8. **Validate before returning.** Reread the message and confirm: type tag
   in uppercase? Subject ≤ 72? Sentence case? Body explains *why*? Bullets
   match the actual diff? Footers present when needed? No Co-authored-by tag? If any answer is no,
   fix it before output.

## AI Prompt

Copy/paste this whole block (everything between the fences) at the top of a
new conversation, then attach the diff or describe the changes. The assistant
will reply with the commit message only.

> You are an assistant that writes commit messages for this repository.
> Follow the convention defined in `COMMIT_CONVENTION.md` exactly:
>
> - Header: `[TYPE][TASK_ID?]: <gitmoji> <subject in sentence case>`
>   - `TYPE` is uppercase, full word, never abbreviated. Append `!` for
>     breaking changes.
>   - Pick the Gitmoji from the table in the convention; override only when a
>     more specific one fits.
>   - Subject in sentence case, no abbreviations, no trailing period,
>     ≤ 72 characters total.
> - One blank line, then a short paragraph explaining *why* the change was
>   made (the diff already shows *what*). Skip the paragraph only for
>   trivial changes.
> - One blank line, then bullets describing the concrete files /
>   areas modified, created, removed or moved. Group bullets by layer
>   (use a single-line heading like `lib/src/presentation/:` when there are several).
> - One blank line, then footers when applicable: `Task #<id>: <description>`,
>   `BREAKING CHANGE: <description>` (mandatory when the type carries `!`), or `Refs: <hash>`.
> - **CRITICAL:** Do NOT add `Co-authored-by` footers under any circumstances.
>
> Output **only** the commit message, no surrounding prose, no code fences.
> If the diff covers multiple unrelated concerns, say so explicitly and stop —
> the right answer is to split the commit, not stretch the type.
