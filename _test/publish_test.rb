# Fails when a repo file would reach the public site.
# Mirrors Jekyll's entry filter: a path publishes unless a part
# starts with "." or "_", or `exclude` in _config.yml names it.
require "yaml"

root = File.expand_path("..", __dir__)
exclude = YAML.load_file(File.join(root, "_config.yml"))["exclude"] || []
files = `git -C #{root} ls-files`.split("\n")

published = files.reject do |f|
  f.split("/").any? { |p| p.start_with?(".", "_") } ||
    exclude.any? { |e| f == e || f.start_with?("#{e}/") }
end
private_files = %w[README.md CLAUDE.md]
leaks = published & private_files
abort "FAIL: would publish #{leaks.join(', ')}" unless leaks.empty?
puts "ok: #{published.size} published files, no repo file among them"
