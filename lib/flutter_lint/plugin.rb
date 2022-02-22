# Necessary for flutter analyze --write result that doesn't give rule info
# From https://dart-lang.github.io/linter/lints/options/options.html

FlutterViolation = Struct.new(:rule, :description, :file, :line, :column)

module Danger
  class DangerFlutterLint < Plugin
    # Enable only_modified_files
    # Only show messages within changed files.
    # Default to true
    attr_accessor :only_modified_files

    # Report path
    # You should set output from `flutter analyze` here
    attr_accessor :report_path

    # Allow modify inline mode via flutter_lint
    # attr_accessor :inline_mode

    # Pass modified_files (array of string) to allow only run analyze for modified files
    def lint(modified_files = nil, inline_mode: false)
      @modified_files = modified_files || (git.modified_files - git.deleted_files) + git.added_files
      if File.exist?(report_path.to_s)
        lint_report(File.read(report_path, encoding: 'utf-8'), modified_files, inline_mode: inline_mode)
      else
        if flutter_installed?
          report = if modified_files && !modified_files.empty?
                     `dart analyze #{modified_files.join(' ')}`.chomp
                   else
                     `flutter analyze`.chomp
                   end
          lint_report(report, modified_files, inline_mode: inline_mode)
        else
          fail("Could not run lint without flutter and report file not found")
        end
      end
    end

    # def check_format
    # end

    private

    def flutter_analyzer_violations(report)
      return [] if report.empty? || report.include?('No issues found!')

      report.each_line.map do |line|
        # Ignore error, only include info
        next unless line.include?('info')

        if line.include? '[info]' # For flutter analyze --write=reports.txt reports
          description, file_line = line.delete_prefix('[info]').strip.split('(')
          file_line = file_line.delete_suffix(')')
          file_relative_path = @modified_files.find { |file| file_line.include?(file) }
          rule = description
          # Can map rules, but too much effort, just consider rule = description
          # DART_RULES = {
          #   'name types using UpperCamelCase' => 'camel_case_types',
          #   'Prefer const with constant constructors' => 'prefer_const_constructors'
          # }.freeze
          # rule = DART_RULES[description]
        elsif line.include? ('•') # For flutter analyze result
          _, description, file_line, rule = line.split('•').map(&:strip)
        elsif line.include? ('-') # For dart analyze modified_files result
          _, file_line, description, rule = line.split('-').map(&:strip)
        end
        file, line_number, column = file_line.split(':')
        file = file_relative_path if file_relative_path
        FlutterViolation.new(rule, description, file, line_number.to_i, column.to_i)
      end.compact
    end

    def lint_report(report, modified_files, inline_mode: false)
      violations = flutter_analyzer_violations(report)
      lint_mode(violations, inline_mode: inline_mode)
    end

    def lint_mode(violations, inline_mode: false)
      if inline_mode
        send_inline_comments(violations)
      else
        markdown(summary_table(violations))
      end
    end

    def send_inline_comments(violations)
      filtered_violations = filtered_violations(violations)

      filtered_violations.each do |violation|
        send("warn", violation.description, file: violation.file, line: violation.line)
      end
    end

    def summary_table(violations)
      filtered_violations = filtered_violations(violations)

      # We don't need report when nothing is wrong?
      if filtered_violations.empty?
        return '### Flutter Analyze found 0 issues ✅'
      else
        return markdown_table(filtered_violations)
      end
    end

    # Should fail on invalid linters?
    def markdown_table(violations)
      table = "### Flutter Analyze found #{violations.length} issues ❌\n\n"
      table << "| File | Line | Rule |\n"
      table << "| ---- | ---- | ---- |\n"

      return violations.reduce(table) { |acc, violation| acc << table_row(violation) }
    end

    def table_row(violation)
      "| `#{violation.file}` | #{violation.line} | #{violation.rule} |\n"
    end

    def filtered_violations(violations)
      report_modified_files = only_modified_files.nil? ? true : only_modified_files
      return violations unless report_modified_files

      violations.select { |violation| @modified_files.include? violation.file }
    end

    def flutter_installed?
      !`command -v flutter`.to_s.strip.empty?
    end
  end
end
