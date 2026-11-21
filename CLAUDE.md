# stormward-site

Support and privacy pages for Stormward, an iPad game.
A Jekyll site that GitHub Pages builds from `main`.

- A merge to `main` publishes at once: keep repo files off the site.
- Jekyll skips dot files and `_` names; it publishes every other file.
- List each file that is not a page or an asset in `exclude` in
  `_config.yml`.
- After a merge that adds such a file, check that it answers 404 on
  the live site.
- `privacy.md` is the operator's public statement: change it only on
  the operator's word.
