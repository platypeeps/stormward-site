# stormward-site

Support and privacy pages for Stormward, an iPad game.
A Jekyll site that GitHub Pages builds from `main`.

- A merge to `main` publishes at once: keep repo files off the site.
- List every non-page file at the top level in `exclude` in `_config.yml`.
- Run `ruby _test/publish_check_test.rb` and `ruby _test/publish_test.rb`
  before a merge; add a new page to `PAGES` in `publish_test.rb`.
- `privacy.md` is the operator's public statement: change it only on
  the operator's word.
