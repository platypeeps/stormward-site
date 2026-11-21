# Fails when a tracked file other than a public page or asset could
# reach the site. It does not model Jekyll's filter. It allows only
# paths whose fate is plain:
# - the public pages and assets/;
# - repo files under a top-level name that starts with . or _ and is
#   not one Jekyll reads (_posts, _drafts): REPO_PATHS;
# - files under a top-level name `exclude` lists exactly.
# _config.yml may set only CONFIG_KEYS, so no `include`, collection
# or plugin can publish a skipped path. `include` then keeps its
# default, .htaccess, which wins over exclude: no path part may start
# with it.
# Run: ruby _test/publish_test.rb [checkout [commit]]
require "yaml"
require "open3"

PAGES = %w[index.md game.md changes.md credits.md privacy.md roadmap.md]
REPO_PATHS = %w[.gitignore .claude _config.yml _layouts _test]
CONFIG_KEYS = %w[title defaults exclude]

# Pages deploys a commit, not the index or the working tree. Resolve
# the candidate commit once, then read the file list, the modes and
# _config.yml from that one commit.
# Git takes repo-local variables (GIT_DIR, GIT_OBJECT_DIRECTORY, ...)
# over -C, and replace refs swap a commit for another: a hook or
# caller could point every read at other content. Clear them all.
vars, status = Open3.capture2("git", "rev-parse", "--local-env-vars")
abort "FAIL: git rev-parse --local-env-vars failed" unless status.success?
vars.split.each { |v| ENV.delete(v) }
ENV["GIT_NO_REPLACE_OBJECTS"] = "1"
root = ARGV[0] || File.expand_path("..", __dir__)
rev = ARGV[1] || "HEAD"
sha, status = Open3.capture2("git", "-C", root, "rev-parse", "--verify",
                             "--quiet", "--end-of-options", "#{rev}^{commit}")
abort "FAIL: no commit #{rev} in #{root}" unless status.success?
sha = sha.strip
# -r -z lists every blob and submodule with its mode, NUL-separated;
# --full-tree lists from the root even when root is a subdirectory.
out, status = Open3.capture2("git", "-C", root, "ls-tree", "-r", "-z",
                             "--full-tree", sha)
abort "FAIL: git ls-tree failed in #{root}" unless status.success?
yml, status = Open3.capture2("git", "-C", root, "show", "#{sha}:_config.yml")
abort "FAIL: no _config.yml in #{sha}" unless status.success?
config = YAML.safe_load(yml) || {}
abort "FAIL: _config.yml is not a mapping" unless config.is_a?(Hash)
exclude = config.fetch("exclude", [])
unless exclude.is_a?(Array) && exclude.all? { |e| e.is_a?(String) }
  abort "FAIL: _config.yml exclude is not a list of strings"
end

entries = out.split("\0").map do |e|
  meta, path = e.split("\t", 2)
  [meta.split(" ").first, path]
end
files = entries.map(&:last)
special = entries.reject { |mode, _| %w[100644 100755].include?(mode) }
unknown = config.keys - CONFIG_KEYS
# Jekyll's default include, .htaccess, wins over exclude and matches
# any name it prefixes, at any level: such a path always fails.
leaks = files.reject do |f|
  next false if f.split("/").any? { |p| p.start_with?(".htaccess") }
  top = f.split("/").first
  PAGES.include?(f) || top == "assets" ||
    REPO_PATHS.include?(top) || exclude.include?(top)
end
errors = []
errors << "_config.yml sets #{unknown.join(', ')}" unless unknown.empty?
unless special.empty?
  errors << "not a plain file: #{special.map(&:last).join(', ')}"
end
errors << "would publish #{leaks.join(', ')}" unless leaks.empty?
abort "FAIL: #{errors.join('; ')}" unless errors.empty?
puts "ok: #{files.size} files, each a public page, an asset or skipped"
