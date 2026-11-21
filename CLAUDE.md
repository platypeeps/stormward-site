# stormward-site

Support and privacy pages for Stormward, an iPad game.
A Jekyll site that GitHub Pages builds from `main`.

- The repo is public: put nothing private in it, on the site or off.
- A merge to `main` publishes at once: keep repo files off the site.
- Jekyll skips dot files and `_` names; it publishes every other file.
- Pages renders a Markdown file at its `.html` path, and a `README.md`
  as its folder's index.
- List each file that is not a page or an asset in `exclude` in
  `_config.yml`.
- After a merge that adds such a file, check on the live site that its
  path and its `.html` path answer 404: a miss is clutter, not a leak.
- `privacy.md` is the operator's public statement: change it only on
  the operator's word.
