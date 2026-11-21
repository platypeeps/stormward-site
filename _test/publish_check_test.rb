# Runs publish_test.rb against fixture checkouts.
# Run: ruby _test/publish_check_test.rb
require "minitest/autorun"
require "open3"
require "tmpdir"
require "fileutils"

class PublishCheckTest < Minitest::Test
  CHECK = File.join(__dir__, "publish_test.rb")
  ROOT = File.expand_path("..", __dir__)

  def run_check(dir, env = {})
    Open3.capture2e(env, "ruby", CHECK, dir)
  end

  # A git checkout under the worktree, its name holding a space.
  def fixture(files)
    Dir.mktmpdir("fixture site", ROOT) do |dir|
      files.each do |path, body|
        FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
        File.write(File.join(dir, path), body)
      end
      system("git", "-C", dir, "init", "-q", exception: true)
      system("git", "-C", dir, "add", "-f", ".", exception: true)
      yield dir
    end
  end

  def test_unlisted_file_fails
    fixture("_config.yml" => "exclude: [README.md]\n",
            "index.md" => "x", "CLAUDE.local.md" => "x") do |dir|
      out, st = run_check(dir)
      refute st.success?, out
      assert_includes out, "CLAUDE.local.md"
    end
  end

  def test_public_pages_and_assets_pass
    fixture("_config.yml" => "exclude: [README.md]\n",
            "index.md" => "x", "README.md" => "x",
            "assets/a b.png" => "x", ".claude/settings.json" => "{}",
            "_layouts/default.html" => "x") do |dir|
      out, st = run_check(dir)
      assert st.success?, out
      assert_includes out, "ok: 2 published files, all public"
    end
  end

  def test_failed_git_listing_fails
    fixture("_config.yml" => "exclude: []\n", "index.md" => "x") do |dir|
      out, st = run_check(dir, "GIT_DIR" => File.join(dir, "no-git"))
      refute st.success?, out
      assert_includes out, "git ls-files failed"
    end
  end
end
