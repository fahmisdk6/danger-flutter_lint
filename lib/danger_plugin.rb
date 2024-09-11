# Necessary for flutter analyze --write result that doesn't give rule info
# From https://dart-lang.github.io/linter/lints/options/options.html

FlutterViolation = Struct.new(:rule, :description, :file, :line, :column)

module Danger
  class DangerFlutterLint < Plugin
    class InvalidReportError < StandardError
      def initialize(message = 'Invalid report_path and flutter is not installed')
        super(message)
      end
    end

    class FlutterUnavailableError < StandardError
      def initialize(message = 'Cannot run flutter, flutter is not installed')
        super(message)
      end
    end

    # Report path
    # You should set output from `flutter analyze` / `dart analyze` here
    attr_accessor :report_path

    # Warning only, instead of fail
    # Default to false
    attr_accessor :warning_only

    # Report 0 issues found on success
    # Default to false
    attr_accessor :report_on_success

    # Enable only_modified_files
    # Only show messages within changed files.
    # Default to true
    attr_accessor :only_modified_files

    # Allow modify inline mode via flutter_lint
    # attr_accessor :inline_mode

    def lint(inline_mode: false, &filter_block)
      @report_type = warning_only ? 'warn' : 'fail'

      # Allow modify result with filter block statement
      # Array<FlutterViolatio>(:rule, :description, :file, :line, :column)
      report = lint_report(@files)

      @modified_files = @files || (git.modified_files - git.deleted_files + git.added_files).filter { |file| file.end_with?('.dart') }
      violations = parse_flutter_violations(report)
      violations = filter_modified_files_violations(violations)
      violations = violations.filter { |violation| filter_block.call(violation) } if filter_block

      inline_mode ? send_inline_comments(violations) : send_markdown_comment(violations)
    end

    # Pass modified_files (array of string) to allow only run analyze for modified files
    def lint_files(files, inline_mode: false, &filter_block)
      @files = files.filter { |file| file.end_with?('.dart') }
      lint(inline_mode: inline_mode, &filter_block)
    end

    # Check dart format status
    # @param path [String] Path of the file that wants to be run on dart format
    #   Path to run dart format on, by default will run on all directory, ('.'),
    #   You can pass glob lib/**/*.dart, and specific dart_files lib/main.dart lib/utils.dart
    def check_format(path = '.')
      raise FlutterUnavailableError unless flutter_installed?

      # dart format -o json .
      # not really helpful as it only display the newly formatted on source
      # { "path": "lib/main.dart", "source": "", "selection": { "offset": -1, "length": -1 } }
      #
      # so we'll just check for changed files
      # dart format -o none .
      # Changed lib/main.dart
      # Formatted 3 files (1 changed) in 0.70 seconds.

      format_result = `dart format -o none #{path}`.chomp.split("\n")
      summary_regex = /Formatted (?<scanned>\S+) files \((?<formatted>\S+) changed\) in (?<time>\S+) seconds./
      summary = summary_regex.match(format_result.last)
      scanned = summary['scanned']
      formatted = summary['formatted']
      prefix = "### Dart Format scanned #{scanned} files,"
      if formatted.to_i.zero?
        markdown "#{prefix} found #{formatted} issues ✅" if report_on_success
      else
        active_files = (git.modified_files - git.deleted_files + git.added_files)
        formatted_files = format_result.map { |line| line.split(' ').last if line.match?(/^Changed/) }.compact
        if only_modified_files.nil? || only_modified_files == true
          formatted_files = formatted_files.filter { |file| active_files.include? file }
        end
        report_type = warning_only ? 'warn' : 'fail'
        message = "#{prefix} found formatting issues on #{formatted_files.size} file(s):\n- #{formatted_files.join("\n- ")}"
        public_send(report_type, message)
      end
    end

    private

    # return flutter report
    def lint_report(files)
      return File.read(report_path, encoding: 'utf-8') if File.exist?(report_path.to_s)

      # Run flutter analyze if report_path is not set and flutter is installed
      if flutter_installed?
        return `dart analyze #{files.join(' ')}`.chomp if files && !files.empty?

        `flutter analyze`.chomp
      else
        raise InvalidReportError
      end
    end

    # return Array<FlutterViolation>
    def parse_flutter_violations(report)
      return [] if report.empty? || report.include?('No issues found!')

      lines = report.split("\n")
      lines.map.with_index do |line, index|
        next unless %w(info error warning).any? { |type| line.match?(/^(\[|\s+)?#{type}/) }

        if line.match?(/^\[(info|error|warning)\]/) # For flutter analyze --write=reports.txt reports
          prefix = line.include?('[info]') ? '[info]' : '[error]'
          line = line.strip.delete_prefix(prefix)
          description, file_line = line.split('(').map(&:strip)
          file_line = file_line.delete_suffix(')')
          file_relative_path = @modified_files.find { |file| file_line.include? file }
          rule = description
          # Can map rules, but too much effort, just consider rule = description
          # DART_RULES = {
          #   'name types using UpperCamelCase' => 'camel_case_types',
          #   'Prefer const with constant constructors' => 'prefer_const_constructors'
          # }.freeze
          # rule = DART_RULES[description]
          puts("if branch 1 #{file_line}'");
        elsif line.include?('•') # For flutter analyze result
          line = "#{line} #{lines[index + 1].strip}" if line.end_with?('•')
          _, description, file_line, rule = line.split('•').map(&:strip)
          puts("if branch 2 #{file_line}'");
        elsif line.include?('-') # For dart analyze modified_files result
          _, file_line, description, rule = line.split('-').map(&:strip)
          file_name = file_line.split(':').first
          file_relative_path = @modified_files.find { |file| file.include? file_name }
          puts("if branch 3 #{file_line}'");
        else
          puts("if branch 4 #{file_line}'");
        end
        file, line_number, column = file_line.split(':')
        file = file_relative_path if file_relative_path
        FlutterViolation.new(rule, description, file, line_number.to_i, column.to_i)
      end.compact
    end

    def send_inline_comments(violations)
      violations.each do |violation|
        public_send(@report_type, violation.description, file: violation.file, line: violation.line)
      end
    end

    def send_markdown_comment(violations)
      if violations.empty?
        markdown '### Flutter Analyze found 0 issues ✅' if report_on_success
      else
        public_send(@report_type, markdown_table(violations))
      end
    end

    def markdown_table(violations)
      table = "### Flutter Analyze found #{violations.length} issues ❌\n\n"
      table << "| File | Line | Rule |\n"
      table << "| ---- | ---- | ---- |\n"

      violations.reduce(table) { |acc, violation| acc << table_row(violation) }
    end

    def table_row(violation)
      "| `#{violation.file}` | #{violation.line} | #{violation.rule} |\n"
    end

    def filter_modified_files_violations(violations)
      return violations unless only_modified_files.nil? || only_modified_files == true

      violations.filter { |violation| @modified_files.include? violation.file }
    end

    def flutter_installed?
      system 'which flutter > /dev/null 2>&1'
    end
  end
end
