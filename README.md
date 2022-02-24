# danger-flutter_lint

[![Gem](https://img.shields.io/gem/v/danger-flutter_lint.svg)](https://rubygems.org/gems/danger-flutter_lint)
[![Build Status](https://travis-ci.org/mateuszszklarek/danger-flutter_lint.svg?branch=master)](https://travis-ci.org/mateuszszklarek/danger-flutter_lint)
[![codecov](https://codecov.io/gh/mateuszszklarek/danger-flutter_lint/branch/master/graph/badge.svg)](https://codecov.io/gh/mateuszszklarek/danger-flutter_lint)

A Danger Plugin to lint dart files using `flutter analyze` command line interface.

## Installation

Add this line to your application's Gemfile:

	$ gem 'danger-flutter_lint'

Or install it yourself as:

    $ gem install danger-flutter_lint

## Usage

Here are the steps you need to use this plugin

### Use directly on CI with a runner that have flutter installed

If your pipeline runner already has flutter installed, you can easily use `flutter_lint` by adding this to your `Dangerfile`

```ruby
flutter_lint.lint
```

By default, if you don't set up anything for the linter, we will generate report for the whole project using `flutter analyze` and use it to report the project.

But if you're working on such a large project, we don't recommend you to use this. You can pass the `modified_files` on the `linter` in which case we will run `dart analyze modified_files` that will only analyze certain files.

```ruby
active_files = (git.modified_files - git.deleted_files) + git.added_files
flutter_lint.lint(active_files.filter { |path| path.match?(/.*\.dart$/) })
```

### Use report file

You can generate report from `flutter analyze` for a full project to a file by using this command

```sh
$ flutter analyze > analyze_report.txt
```

Or if you only work on larger project, and only need to check linter for specific files/modified files, you can use `dart analyze`

```sh
$ dart analyze lib/file1.dart lib/file2.dart > analyze_report.txt
```

Actually `dart analyzer` has a lot more options, such as `--format=machine` and `--format=json` but we currently **don't** support it, currently we only support the default human readable report.

Then, you can also use Flutter built-in function using this command:

```sh
$ flutter analyze --write=_analyze_report.txt
```

But as the report generated from this command isn't as good as the other methods on current version of Flutter (2.10), we don't recommend you to use it. This built-in command only generate the `description` and doesn't give the `rule` violation, it also always generate absolute path of the file, instead of the relative one, and the report won't be as good as the others.

Now you need to set `report_path` and invoke `lint` in your Dangerfile.

```ruby
flutter_lint.report_path = "analyze_report.txt"
flutter_lint.lint
```

This will add markdown table with summary into your PR.

If you want danger to directly comment on the changed lines instead of printing a Markdown table (GitHub only), you can use this

```ruby
flutter_lint.lint(inline_mode: true)
```

Default value for `inline_mode` parameter is `false`.

#### Lint only added/modified files

If you're dealing with a legacy project, with tons of warnings, you may want to lint only new/modified files. You can easily achieve that, setting the `only_modified_files` parameter to `true`.

```ruby
flutter_lint.only_modified_files = true
flutter_lint.report_path = "flutter_analyze_report.txt"
flutter_lint.lint
```

Default value for `only_modified_files` parameter is `true`.

It's also possible to pass a block to filter out any violations after flutter analyze has been run. Here's an example filtering out all violations that didn't occur in the current changes, using the third party gem `git_diff_parser`:

```rb
require 'git_diff_parser'

active_files = (git.modified_files + git.added_files).sort.uniq
patches = GitDiffParser.parse(git.diff.patch)
prefix_pwd = "#{Dir.pwd}/"
# Violation is FlutterViolation(:rule, :description, :file, :line, :column)
swiftlint.lint_files(inline_mode: true) { |violation|
  # To transform absolute path to relative path from `flutter analyze --write=report.txt` result
  filename = violation.file.delete_prefix(prefix_pwd)
  file_patch = patches.find_patch_by_file(filename)
  # Filter out unchanged lines
  !file_patch.nil? && file_patch.changed_lines.any? { |line| line.number == violation.line}
}
```

## Development

1. Clone this repo
2. Run `bundle install` to setup dependencies.
3. Run `bundle exec rake spec` to run the tests.
4. Use `bundle exec guard` to automatically have tests run as you make changes.
5. Make your changes.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mateuszszklarek/danger-flutter_lint.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
