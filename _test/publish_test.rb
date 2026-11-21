# Fails when a file outside the public pages and assets would reach
# the site. Mirrors Jekyll's entry filter: a path publishes unless a
# part starts with "." or "_", or `exclude` in _config.yml names it.
# Run: ruby _test/publish_test.rb [checkout]
require "yaml"
require "open3"

PAGES = %w[index.md game.md changes.md credits.md privacy.md roadmap.md]

root = ARGV[0] || File.expand_path("..", __dir__)
exclude = YAML.load_file(File.join(root, "_config.yml"))["exclude"] || []
out, status = Open3.capture2("git", "-C", root, "ls-files", "-z")
abort "FAIL: git ls-files failed in #{root}" unless status.success?

published = out.split("\0").reject do |f|
  f.split("/").any? { |p| p.start_with?(".", "_") } ||
    exclude.any? { |e| f == e || f.start_with?("#{e}/") }
end
leaks = published.reject { |f| PAGES.include?(f) || f.start_with?("assets/") }
abort "FAIL: would publish #{leaks.join(', ')}" unless leaks.empty?
puts "ok: #{published.size} published files, all public pages or assets"
