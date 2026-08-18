# Neovim Git Workflow Reference

## Tools

- **Neogit** — primary git UI (status, staging files, committing, rebasing, etc.)
- **Gitsigns** — inline hunk operations, blame, side-by-side diffs (operates on the current buffer)
- **Snacks pickers** — floating pickers for browsing diffs, blame, and file history with syntax-highlighted previews

## Keybindings

### Neogit (`<leader>g`)

- `<leader>gg` — open Neogit status (replaces current buffer, navigate away with Ctrl-Tab)
- `<leader>gl` — git log (all references, graph view)
- `<leader>gL` — git log menu (choose log type)

### Snacks Pickers (`<leader>g`)

- `<leader>gb` — **blame line** — shows commit log for current line in a picker with diff preview
- `<leader>gf` — **file history** — commit log for current file with diff previews

### Gitsigns — Hunk Operations (`<leader>gh`)

All of these work on the current file buffer. For **line-level** staging/resetting, visually select lines first, then use the same keybinding.

- `<leader>ghs` — stage hunk (or selected lines in visual mode)
- `<leader>ghr` — reset hunk (or selected lines in visual mode)
- `<leader>ghS` — stage entire buffer
- `<leader>ghu` — undo last stage hunk
- `<leader>ghR` — reset entire buffer
- `<leader>ghp` — preview hunk inline (shows what changed as virtual text)

### Gitsigns — Blame (`<leader>gh`)

- `<leader>ghb` — blame line (floating popup with full commit info)
- `<leader>ghB` — blame buffer (full git blame view in a side panel, close with `q`)

### Gitsigns — Diff (`<leader>g`)

- `<leader>gd` — diff current file against the index (staged version) in a side-by-side split with full syntax highlighting; close the diff with `q`
- `<leader>gD` — diff current file against the previous revision (last commit)

### Gitsigns — Navigation (`]`/`[`)

- `]h` / `[h` — next/prev hunk
- `]H` / `[H` — last/first hunk
- `ih` — text object: select hunk (works with operators like `d`, `y`, `v`)

## Common Workflows

### Quick stage & commit
1. Edit files normally
2. `]h` / `[h` to jump between hunks, `<leader>ghp` to preview
3. `<leader>ghs` to stage hunks (or visual select lines first for partial staging)
4. `<leader>gg` to open Neogit, then `cc` to commit

### Review my changes before committing
1. `<leader>gg` — open Neogit status for the full picture: all changed files, staged vs. unstaged, with hunk-level detail
2. Or review per file: open a file and `<leader>gd` for a side-by-side diff against the staged version (`q` to close)
3. Stage from Neogit, or `<leader>ghs` to stage hunks inline (visual-select lines first for partial staging)

### Review a file's diff side-by-side
1. Open the file
2. `<leader>gd` — opens a split with the index (staged) version on one side and your working changes on the other
3. Both sides have full syntax highlighting
4. `<leader>gD` instead diffs against the previous commit
5. Close the diff with `q` (or `:q` on the diff buffer)

### Investigate who changed a line
- Quick: `<leader>ghb` — popup with blame info for current line
- Full: `<leader>ghB` — full buffer blame view (close with `q`)
- Rich: `<leader>gb` — Snacks picker showing commit log for current line with diff previews

### Browse a file's history
1. `<leader>gf` — Snacks picker showing all commits that touched the current file
2. Select a commit to see its diff in the preview pane

### Selective line-level staging
1. Enter visual mode (`v` or `V`)
2. Select the specific lines you want to stage
3. `<leader>ghs` — stages only the selected lines
4. Works the same for resetting: visual select + `<leader>ghr`
