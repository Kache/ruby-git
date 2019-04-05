#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../test_helper'

class TestDiff < Test::Unit::TestCase
  def setup
    set_file_paths
    @git = Git.open(@wdir)
    @diff = @git.diff('gitsearch1', 'v2.5')
  end

  #def test_diff
  #  g.diff
  #  assert(1, d.size)
  #end

  def test_diff_current_vs_head
    #test git diff without specifying source/destination commits
    update_file(File.join(@wdir,"example.txt"),"FRANCO")
    d = @git.diff
    patch = d.patch
    assert(patch.match(/\+FRANCO/))
  end

  def test_diff_tags
    d = @git.diff('gitsearch1', 'v2.5')
    assert_equal(3, d.size)
    assert_equal(74, d.lines)
    assert_equal(10, d.deletions)
    assert_equal(64, d.insertions)
  end

  # Patch files on diff outputs used to be parsed as
  # part of the diff adding invalid modificaction
  # to the diff results.
  def test_diff_patch
    d = @git.diff('diff_over_patches~2', 'diff_over_patches')
    assert_equal(1, d.count)
  end

  def test_diff_path
    d = @git.diff('gitsearch1', 'v2.5').path('scott/')
    assert_equal(d.from, 'gitsearch1')
    assert_equal(d.to, 'v2.5')
    assert_equal(2, d.size)
    assert_equal(9, d.lines)
    assert_equal(9, d.deletions)
    assert_equal(0, d.insertions)
  end

  def test_diff_objects
    d = @git.diff('gitsearch1', @git.gtree('v2.5'))
    assert_equal(3, d.size)
  end

  def test_object_diff
    d = @git.gtree('v2.5').diff('gitsearch1')
    assert_equal(3, d.size)
    assert_equal(74, d.lines)
    assert_equal(10, d.insertions)
    assert_equal(64, d.deletions)

    d = @git.gtree('v2.6').diff(@git.gtree('gitsearch1'))
    assert_equal(2, d.size)
    assert_equal(9, d.lines)
  end

  def test_diff_stats
    s = @diff.stats
    assert_equal(3, s[:total][:files])
    assert_equal(74, s[:total][:lines])
    assert_equal(10, s[:total][:deletions])
    assert_equal(64, s[:total][:insertions])

    # per file
    assert_equal(1, s[:files]["scott/newfile"][:deletions])
  end

  def test_diff_hashkey
    assert_equal('5d46068', @diff["scott/newfile"].src)
    assert_nil(@diff["scott/newfile"].blob(:dst))
    assert(@diff["scott/newfile"].blob(:src).is_a?(Git::Object::Blob))
  end

  def test_patch
    p = @git.diff('v2.8^', 'v2.8').patch
    diff = "diff --git a/example.txt b/example.txt\nindex 1f09f2e..8dc79ae 100644\n--- a/example.txt\n+++ b/example.txt\n@@ -1 +1 @@\n-replace with new text\n+replace with new text - diff test\n"
    assert_equal(diff, p)
  end

  def test_diff_each
    files = {}
    @diff.each do |d|
      files[d.path] = d
    end

    assert(files['example.txt'])
    assert_equal('100644', files['scott/newfile'].mode)
    assert_equal('deleted', files['scott/newfile'].type)
    assert_equal(161, files['scott/newfile'].patch.size)
  end

  def test_diff_parses_files_incrementally
    mock_patch = Module.new do
      extend self
      alias_method :each_line, :to_enum

      def each
        yield 'diff --git a/file_1.txt b/file_1.txt'
        yield 'injesting file_1 should not injest file_2'
        yield 'diff --git a/file_2.txt b/file_2.txt'
        raise 'file_2 injested'
      end
    end

    @diff.instance_variable_set(:@patch, mock_patch) # "stub"

    diff_files_enum = @diff.each
    diff_file = diff_files_enum.next
    assert 'file_1.txt', diff_file.path

    assert_raises RuntimeError.new('file_2 injested') do
      diff_files_enum.next # file_2
    end
  end

  def test_diff_file_added_lines_deleted_lines
    diff = @git.diff('gitsearch1~', 'gitsearch1')

    newfile_diff = diff['scott/newfile']
    newfile_additions = [Git::Diff::DiffLine.new(1, "you can't search me!\n")]
    assert_equal newfile_additions, newfile_diff.added_lines
    assert_empty newfile_diff.deleted_lines

    text_diff = diff['scott/text.txt']
    text_additions = [
      Git::Diff::DiffLine.new(6, "to search one\n"),
      Git::Diff::DiffLine.new(7, "to search two\n"),
      Git::Diff::DiffLine.new(8, "nothing!\n"),
    ]
    text_deletions = [Git::Diff::DiffLine.new(6, "to searc\n")]
    assert_equal text_additions, text_diff.added_lines
    assert_equal text_deletions, text_diff.deleted_lines
  end

  def test_diff_file_multiple_change_hunks
    diff_file = @git.diff('multi-change-hunks~', 'multi-change-hunks').first

    additions = [
      Git::Diff::DiffLine.new(4,  "first change\n"),
      Git::Diff::DiffLine.new(21, "second change\n"),
    ]
    deletions = [
      Git::Diff::DiffLine.new(4,  "adipiscing\n"),
      Git::Diff::DiffLine.new(5,  "elit, sed do\n"),
      Git::Diff::DiffLine.new(22, "in voluptate\n"),
    ]

    assert_equal additions, diff_file.added_lines
    assert_equal deletions, diff_file.deleted_lines
  end
end
