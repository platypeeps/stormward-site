# Fails when a tracked file other than a public page or asset could
# reach the site. It does not model Jekyll's filter. It allows only
# paths whose fate is plain:
# - the public pages and assets/;
# - repo files under a top-level name that starts with . or _ and is
#   not one Jekyll reads (_posts, _drafts): REPO_PATHS;
# - files under a top-level name `exclude` lists exactly.
# _config.yml may set only CONFIG_KEYS, so no `include`, collection
# or plugin can publish a skipped path. `include` then keeps its
# default, .htaccess, a prefix no repo path starts with.
# Run: ruby _test/publish_test.rb [checkout]
require "yaml"
require "open3"

PAGES = %w[index.md game.md changes.md credits.md privacy.md roadmap.md]
REPO_PATHS = %w[.gitignore .claude _config.yml _layouts _test]
CONFIG_KEYS = %w[title defaults exclude]

# Reads the file list and _config.yml from the index, one snapshot.
root = ARGV[0] || File.expand_path("..", __dir__)
out, status = Open3.capture2("git", "-C", root, "ls-files", "-z")
abort "FAIL: git ls-files failed in #{root}" unless status.success?
yml, status = Open3.capture2("git", "-C", root, "show", ":_config.yml")
abort "FAIL: no staged _config.yml in #{root}" unless status.success?
config = YAML.safe_load(yml) || {}
exclude = config["exclude"] || []

files = out.split("\0")
unknown = config.keys - CONFIG_KEYS
leaks = files.reject do |f|
  top = f.split("/").first
  PAGES.include?(f) || top == "assets" ||
    REPO_PATHS.include?(top) || exclude.include?(top)
end
errors = []
errors << "_config.yml sets #{unknown.join(', ')}" unless unknown.empty?
errors << "would publish #{leaks.join(', ')}" unless leaks.empty?
abort "FAIL: #{errors.join('; ')}" unless errors.empty?
puts "ok: #{files.size} files, each a public page, an asset or skipped"
