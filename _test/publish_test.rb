# Fails when a file outside the public pages and assets would reach
# the site. Mirrors Jekyll 3.10's entry filter, which GitHub Pages
# runs on each directory level: an entry `include` names publishes;
# otherwise one whose name starts with . _ # ~, ends with ~, or that
# `exclude` names is skipped. `include` defaults to [.htaccess].
# Run: ruby _test/publish_test.rb [checkout]
require "yaml"
require "open3"

PAGES = %w[index.md game.md changes.md credits.md privacy.md roadmap.md]

root = ARGV[0] || File.expand_path("..", __dir__)
config = YAML.load_file(File.join(root, "_config.yml")) || {}
include = config.fetch("include", [".htaccess"]) || []
exclude = config["exclude"] || []
out, status = Open3.capture2("git", "-C", root, "ls-files", "-z")
abort "FAIL: git ls-files failed in #{root}" unless status.success?

def match?(globs, path)
  globs.any? do |g|
    g = g.to_s.chomp("/")
    File.fnmatch?(g, path) || path == g || path.start_with?("#{g}/")
  end
end

def kept?(path, include, exclude)
  return true if match?(include, path) || match?(include, File.basename(path))
  name = File.basename(path)
  !(name.start_with?(".", "_", "#", "~") || name.end_with?("~") ||
    match?(exclude, path))
end

published = out.split("\0").select do |f|
  parts = f.split("/")
  (1..parts.size).all? { |n| kept?(parts.first(n).join("/"), include, exclude) }
end
leaks = published.reject { |f| PAGES.include?(f) || f.start_with?("assets/") }
abort "FAIL: would publish #{leaks.join(', ')}" unless leaks.empty?
puts "ok: #{published.size} published files, all public pages or assets"
