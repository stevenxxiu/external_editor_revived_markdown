# External Editor Revived Markdown
Script to convert to and from *Markdown* when editing.

## Requirements
- Scripting language: *Nushell*
- Editor: *Neovim*
- Terminal: *WezTerm*

Conversion utilities:

- Convert from *HTML* to *Markdown*: [matthewwithanm/python-markdownify: Convert HTML to Markdown](https://github.com/matthewwithanm/python-markdownify)
- Convert from *Markdown* to *HTML*: [Python-Markdown/markdown: A Python implementation of John Gruber’s Markdown with Extension support.](https://github.com/Python-Markdown/markdown)

## Usage
*External Editor Revived* -> `Preferences` -> `Essential`:

- `Shell`: `sh`
- `Command template`: `nu $CLONE_DIR/edit.nu "/path/to/temp.eml"`
