# Runs publish_test.rb against fixture checkouts.
# Run: ruby _test/publish_check_test.rb
require "minitest/autorun"
require "open3"
require "tmpdir"
require "fileutils"

class PublishCheckTest < Minitest::Test
  CHECK = File.join(__dir__, "publish_test.rb")
  ROOT = File.expand_path("..", __dir__)

  # Repository-local git variables the caller may set (GIT_DIR,
  # GIT_INDEX_FILE, ...), cleared so they cannot redirect fixtures.
  GIT_CLEAN = `git rev-parse --local-env-vars`.split.map { |v| [v, nil] }.to_h

  def run_check(dir, env = {}, commit: nil)
    Open3.capture2e(GIT_CLEAN.merge(env), "ruby", CHECK, dir, *commit)
  end

  # Pages deploys commits, so fixtures commit what they stage.
  def commit(dir)
    git("-C", dir, "-c", "user.name=operator",
        "-c", "user.email=operator@example.test",
        "commit", "-q", "--no-verify", "-m", "fixture")
  end

  def head(dir)
    Open3.capture2(GIT_CLEAN, "git", "-C", dir, "rev-parse", "HEAD")[0].strip
  end

  def git(*args)
    system(GIT_CLEAN, "git", *args, exception: true)
  end

  # A git checkout under the worktree, its name holding a space.
  def fixture(files)
    Dir.mktmpdir("fixture site", ROOT) do |dir|
      files.each do |path, body|
        FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
        File.write(File.join(dir, path), body)
      end
      git("-C", dir, "init", "-q")
      git("-C", dir, "add", "-f", ".")
      commit(dir)
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
      assert_includes out, "ok: 6 files"
    end
  end

  def test_failed_git_listing_fails
    fixture("_config.yml" => "exclude: []\n", "index.md" => "x") do |dir|
      out, st = run_check(File.join(dir, "missing"))
      refute st.success?, out
      assert_includes out, "FAIL: no commit HEAD"
    end
  end

  def test_caller_index_file_is_not_used
    Dir.mktmpdir("caller", ROOT) do |caller|
      stray = File.join(caller, "index")
      old = ENV["GIT_INDEX_FILE"]
      ENV["GIT_INDEX_FILE"] = stray
      begin
        fixture("_config.yml" => "exclude: []\n", "index.md" => "x",
                "CLAUDE.local.md" => "x") do |dir|
          out, st = run_check(dir)
          refute st.success?, out
          assert_includes out, "CLAUDE.local.md"
        end
      ensure
        ENV["GIT_INDEX_FILE"] = old
      end
      refute File.exist?(stray), "fixture setup wrote the caller's index"
    end
  end

  def test_included_underscore_file_fails
    fixture("_config.yml" => "include: [_private.md]\n",
            "index.md" => "x", "_private.md" => "x") do |dir|
      out, st = run_check(dir)
      refute st.success?, out
      assert_includes out, "_private.md"
    end
  end

  def test_default_htaccess_fails
    fixture("_config.yml" => "exclude: []\n",
            "index.md" => "x", ".htaccess" => "x") do |dir|
      out, st = run_check(dir)
      refute st.success?, out
      assert_includes out, ".htaccess"
    end
  end

  def test_dated_post_fails
    fixture("_config.yml" => "exclude: []\n", "index.md" => "x",
            "_posts/2026-01-01-notes.md" => "---\n---\nx") do |dir|
      out, st = run_check(dir)
      refute st.success?, out
      assert_includes out, "_posts/2026-01-01-notes.md"
    end
  end

  def test_htaccess_prefix_fails
    fixture("_config.yml" => "exclude: []\n",
            "index.md" => "x", ".htaccess.old" => "x") do |dir|
      out, st = run_check(dir)
      refute st.success?, out
      assert_includes out, ".htaccess.old"
    end
  end

  def test_collection_config_fails
    fixture("_config.yml" => "collections: { notes: { output: true } }\n",
            "index.md" => "x") do |dir|
      out, st = run_check(dir)
      refute st.success?, out
      assert_includes out, "collections"
    end
  end

  def test_excluded_directory_passes
    fixture("_config.yml" => "exclude: [README.md, docs]\n",
            "index.md" => "x", "README.md" => "x",
            "docs/notes.md" => "x") do |dir|
      out, st = run_check(dir)
      assert st.success?, out
    end
  end

  def test_unstaged_config_edit_is_ignored
    fixture("_config.yml" => "exclude: []\n", "index.md" => "x",
            "README.md" => "x") do |dir|
      File.write(File.join(dir, "_config.yml"), "exclude: [README.md]\n")
      out, st = run_check(dir)
      refute st.success?, out
      assert_includes out, "README.md"
    end
  end

  def test_scalar_exclude_fails
    fixture("_config.yml" => "exclude: README.md.bak\n", "index.md" => "x",
            "README.md" => "x") do |dir|
      out, st = run_check(dir)
      refute st.success?, out
      assert_includes out, "exclude"
    end
  end

  def test_non_hash_config_fails
    fixture("_config.yml" => "- exclude\n", "index.md" => "x") do |dir|
      out, st = run_check(dir)
      refute st.success?, out
      assert_includes out, "FAIL: _config.yml"
    end
  end

  def test_asset_symlink_fails
    fixture("_config.yml" => "exclude: [CLAUDE.md]\n", "index.md" => "x",
            "CLAUDE.md" => "x") do |dir|
      File.symlink("../CLAUDE.md", File.join(dir, "assets-link"))
      FileUtils.mkdir_p(File.join(dir, "assets"))
      File.rename(File.join(dir, "assets-link"), File.join(dir, "assets/a.md"))
      git("-C", dir, "add", "-f", "assets/a.md")
      commit(dir)
      out, st = run_check(dir)
      refute st.success?, out
      assert_includes out, "assets/a.md"
    end
  end

  def test_excluded_htaccess_fails
    [".htaccess", ".htaccess.old"].each do |name|
      fixture("_config.yml" => "exclude: [#{name}]\n",
              "index.md" => "x", name => "x") do |dir|
        out, st = run_check(dir)
        refute st.success?, out
        assert_includes out, name
      end
    end
  end

  # Class: the check must read the commit Pages deploys, not the index.

  def test_staged_deletion_is_ignored
    fixture("_config.yml" => "exclude: []\n", "index.md" => "x",
            "README.md" => "x") do |dir|
      git("-C", dir, "rm", "-q", "--cached", "README.md")
      out, st = run_check(dir)
      refute st.success?, out
      assert_includes out, "README.md"
    end
  end

  def test_staged_exclusion_is_ignored
    fixture("_config.yml" => "exclude: []\n", "index.md" => "x",
            "README.md" => "x") do |dir|
      File.write(File.join(dir, "_config.yml"), "exclude: [README.md]\n")
      git("-C", dir, "add", "_config.yml")
      out, st = run_check(dir)
      refute st.success?, out
      assert_includes out, "README.md"
    end
  end

  def test_staged_mode_change_is_ignored
    fixture("_config.yml" => "exclude: [CLAUDE.md]\n", "index.md" => "x",
            "CLAUDE.md" => "x") do |dir|
      FileUtils.mkdir_p(File.join(dir, "assets"))
      File.symlink("../CLAUDE.md", File.join(dir, "assets/a.md"))
      git("-C", dir, "add", "-f", "assets/a.md")
      commit(dir)
      File.delete(File.join(dir, "assets/a.md"))
      File.write(File.join(dir, "assets/a.md"), "x")
      git("-C", dir, "add", "-f", "assets/a.md")
      out, st = run_check(dir)
      refute st.success?, out
      assert_includes out, "not a plain file: assets/a.md"
    end
  end

  def test_named_commit_is_checked
    fixture("_config.yml" => "exclude: []\n", "index.md" => "x",
            "README.md" => "x") do |dir|
      leaky = head(dir)
      git("-C", dir, "rm", "-q", "README.md")
      commit(dir)
      out, st = run_check(dir, commit: leaky)
      refute st.success?, out
      assert_includes out, "README.md"
      out, st = run_check(dir)
      assert st.success?, out
    end
  end

  def test_unborn_head_fails
    Dir.mktmpdir("fixture site", ROOT) do |dir|
      File.write(File.join(dir, "_config.yml"), "exclude: []\n")
      git("-C", dir, "init", "-q")
      git("-C", dir, "add", "_config.yml")
      out, st = run_check(dir)
      refute st.success?, out
      assert_includes out, "FAIL: no commit HEAD"
    end
  end

  # Class: a read the caller can redirect away from the commit the
  # checkout names. Git takes repo-local variables (GIT_DIR, ...) over
  # -C, and replace refs swap a commit for another.

  def test_caller_git_dir_is_not_used
    fixture("_config.yml" => "exclude: []\n", "index.md" => "x") do |clean|
      fixture("_config.yml" => "exclude: []\n", "index.md" => "x",
              "README.md" => "x") do |dir|
        out, st = run_check(dir, { "GIT_DIR" => File.join(clean, ".git") })
        refute st.success?, out
        assert_includes out, "README.md"
      end
    end
  end

  def test_replace_ref_is_not_used
    fixture("_config.yml" => "exclude: []\n", "index.md" => "x",
            "README.md" => "x") do |dir|
      leaky = head(dir)
      git("-C", dir, "rm", "-q", "README.md")
      commit(dir)
      git("-C", dir, "replace", leaky, head(dir))
      out, st = run_check(dir, commit: leaky)
      refute st.success?, out
      assert_includes out, "README.md"
    end
  end

  def test_subdirectory_checkout_lists_whole_tree
    fixture("_config.yml" => "exclude: []\n", "index.md" => "x",
            "README.md" => "x", "assets/a.png" => "x") do |dir|
      out, st = run_check(File.join(dir, "assets"))
      refute st.success?, out
      assert_includes out, "README.md"
    end
  end
end
