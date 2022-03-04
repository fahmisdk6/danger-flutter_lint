# frozen_string_literal: true

require File.expand_path('spec_helper', __dir__)

module Danger
  describe Danger::DangerFlutterLint do
    let(:dangerfile) { testing_dangerfile }
    let(:flutter_lint) { dangerfile.flutter_lint }

    it 'should be a danger plugin' do
      expect(Danger::DangerFlutterLint.new(nil)).to be_a Danger::Plugin
    end

    describe 'with a Dangerfile' do
      context 'check format' do
        context 'when flutter is not installed' do
          before do
            allow(flutter_lint).to receive(:system).with('which flutter > /dev/null 2>&1').and_return(false)
          end

          it 'raises FlutterUnavailableError' do
            expect { flutter_lint.check_format }.to raise_error(DangerFlutterLint::FlutterUnavailableError)
          end
        end

        context 'when is installed' do
          before do
            allow(flutter_lint).to receive(:system).with('which flutter > /dev/null 2>&1').and_return(true)
          end

          context 'when path is set' do
            context 'when no formatting issue' do
              before do
                allow(flutter_lint).to receive(:`).with('dart format -o none lib').and_return('Formatted 200 files (0 changed) in 0.2 seconds.')
              end

              it 'should not fail' do
                flutter_lint.check_format('lib')

                expect(flutter_lint.status_report[:errors]).to be_empty
              end

              it 'should not fail but report success summary' do
                flutter_lint.report_on_success = true
                flutter_lint.check_format('lib')

                expected = '### Dart Format scanned 200 files, found 0 issues ✅'
                expect(flutter_lint.status_report[:markdowns].first.message).to eq(expected)
                expect(flutter_lint.status_report[:errors]).to be_empty
              end

              context 'when there are some formatting issue' do
                before do
                  allow(flutter_lint.git).to receive(:deleted_files).and_return([])
                  allow(flutter_lint.git).to receive(:added_files).and_return(['lib/appinfo/lib/appinfo.dart'])
                  allow(flutter_lint.git).to receive(:modified_files).and_return([])
                  allow(flutter_lint).to receive(:`).with('dart format -o none lib').and_return(File.read('spec/fixtures/dart_format_violations.txt'))
                end

                it 'should report fail on all files when only modified files is off' do
                  flutter_lint.only_modified_files = false
                  flutter_lint.check_format('lib')

                  expected = [
                    '### Dart Format scanned 200 files, found formatting issues on 7 file(s):',
                    '- lib/appinfo/impl/appinfo_package_info/lib/src/appinfo_package_info.dart',
                    '- lib/appinfo/impl/appinfo_package_info/lib/src/appinfo_package_info_initiator.dart',
                    '- lib/appinfo/impl/appinfo_package_info/test/appinfo_package_info_initiator_test.dart',
                    '- lib/appinfo/impl/appinfo_package_info/test/coverage_test.dart',
                    '- lib/appinfo/lib/appinfo.dart',
                    '- lib/appinfo/test/coverage_test.dart',
                    '- lib/localization/test/coverage_test.dart'
                  ].join("\n")
                  expect(flutter_lint.status_report[:errors]).to eq([expected])
                  expect(flutter_lint.status_report[:errors]).not_to be_empty
                end

                context 'only modified files active' do
                  it 'should report fail on modified files when only modified files is on' do
                    flutter_lint.check_format('lib')

                    expected = [
                      '### Dart Format scanned 200 files, found formatting issues on 1 file(s):',
                      '- lib/appinfo/lib/appinfo.dart'
                    ].join("\n")
                    expect(flutter_lint.status_report[:errors]).to eq([expected])
                    expect(flutter_lint.status_report[:errors]).not_to be_empty
                  end

                  it 'should report warning on warning only active' do
                    flutter_lint.warning_only = true
                    flutter_lint.check_format('lib')

                    expected = [
                      '### Dart Format scanned 200 files, found formatting issues on 1 file(s):',
                      '- lib/appinfo/lib/appinfo.dart'
                    ].join("\n")
                    expect(flutter_lint.status_report[:warnings]).to eq([expected])
                    expect(flutter_lint.status_report[:warnings]).not_to be_empty
                  end
                end
              end
            end
          end

          context 'when path is not set' do
            before do
              allow(flutter_lint).to receive(:`).with('dart format -o none .').and_return('Formatted 200 files (0 changed) in 0.2 seconds.')
            end

            it 'should not fail' do
              flutter_lint.check_format

              expect(flutter_lint.status_report[:errors]).to be_empty
            end
          end
        end
      end

      context 'lint' do
        before do
          # @dangerfile = testing_dangerfile
          # flutter_lint = @dangerfile.flutter_lint
          @modified_files = [
            'lib/home/home_page.dart',
            'lib/profile/user/phone_widget.dart',
            'lib/file.dart',
            'integration_test/app_test.dart'
          ]
          allow(flutter_lint.git).to receive(:deleted_files).and_return([])
          allow(flutter_lint.git).to receive(:added_files).and_return([])
          allow(flutter_lint.git).to receive(:modified_files).and_return(@modified_files)
        end

        context 'when report path is not set or not exist' do
          context 'when flutter is not installed' do
            before do
              allow(flutter_lint).to receive(:system).with('which flutter > /dev/null 2>&1').and_return(false)
            end

            it 'raises InvalidReportError' do
              expect { flutter_lint.lint }.to raise_error(DangerFlutterLint::InvalidReportError)
            end
          end

          context 'when flutter is installed' do
            before do
              allow(flutter_lint).to receive(:system).with('which flutter > /dev/null 2>&1').and_return(true)
            end

            context 'when modified files is set' do
              context 'when report has some violations' do
                before do
                  allow(flutter_lint).to receive(:`)
                    .with("dart analyze #{@modified_files.join(' ')}")
                    .and_return(File.read('spec/fixtures/dart_analyze_files_violations.txt'))
                end

                it 'should fail when lint' do
                  flutter_lint.lint_files(@modified_files)

                  expect(flutter_lint.status_report[:errors]).not_to be_empty
                end

                it 'should print markdown message with 2 violations when inline mode is off' do
                  flutter_lint.lint_files(@modified_files, inline_mode: false)

                  expected = <<~MESSAGE
                  ### Flutter Analyze found 2 issues ❌\n
                  | File | Line | Rule |
                  | ---- | ---- | ---- |
                  | `integration_test/app_test.dart` | 4 | duplicate_import |
                  | `integration_test/app_test.dart` | 11 | avoid_print |
                  MESSAGE

                  expect(flutter_lint.status_report[:errors].first).to eq(expected)
                end

                it 'should send 2 inline comment instead of markdown when inline mode is on' do
                  flutter_lint.lint_files(@modified_files, inline_mode: true)

                  errors = flutter_lint.status_report[:errors]

                  expected_errors = [
                    'Duplicate import. Try removing all but one import of the library.',
                    'Avoid `print` calls in production code.'
                  ]

                  expect(errors).to eq(expected_errors)
                end
              end

              context 'when report has no violations' do
                before do
                  allow(flutter_lint).to receive(:`)
                    .with("dart analyze #{@modified_files.join(' ')}")
                    .and_return(File.read('spec/fixtures/dart_analyze_files_no_violations.txt'))
                end

                it 'should NOT fail when lint' do
                  flutter_lint.lint_files(@modified_files)

                  expect(flutter_lint.status_report[:errors]).to be_empty
                end

                it 'should NOT send anything when inline mode is off and report on success not set' do
                  flutter_lint.lint_files(@modified_files, inline_mode: false)

                  errors = flutter_lint.status_report[:errors]
                  expect(errors).to eq([])
                  expect(errors).to be_empty
                end
              end
            end

            context 'when modified files is not set' do
              context 'when report has some violations' do
                before do
                  allow(flutter_lint).to receive(:`)
                    .with('flutter analyze')
                    .and_return(File.read('spec/fixtures/flutter_analyze_with_violations.txt'))
                end

                it 'shoul fail when lint' do
                  flutter_lint.lint

                  expect(flutter_lint.status_report[:errors]).not_to be_empty
                end

                it 'should print markdown message with 3 violations when inline mode is off & only modified files set to false' do
                  flutter_lint.only_modified_files = false
                  flutter_lint.lint(inline_mode: false)

                  expected = <<~MESSAGE
                ### Flutter Analyze found 3 issues ❌\n
                | File | Line | Rule |
                | ---- | ---- | ---- |
                | `lib/main.dart` | 5 | camel_case_types |
                | `lib/home/home_page.dart` | 13 | prefer_const_constructors |
                | `lib/profile/user/phone_widget.dart` | 19 | avoid_catches_without_on_clauses |
                  MESSAGE

                  expect(flutter_lint.status_report[:errors].first).to eq(expected)
                end

                it 'should send 3 inline comment instead of markdown when inline mode is on & only modified files set to false' do
                  flutter_lint.only_modified_files = false
                  flutter_lint.lint(inline_mode: true)

                  errors = flutter_lint.status_report[:errors]

                  expected_errors = [
                    'Name types using UpperCamelCase',
                    'Prefer const with constant constructors',
                    'AVOID catches without on clauses'
                  ]

                  expect(errors).to eq(errors)
                end

                it 'should print markdown message with 2 violations when inline mode is off & only modified files default to true' do
                  flutter_lint.lint(inline_mode: false)

                  expected = <<~MESSAGE
                ### Flutter Analyze found 2 issues ❌\n
                | File | Line | Rule |
                | ---- | ---- | ---- |
                | `lib/home/home_page.dart` | 13 | prefer_const_constructors |
                | `lib/profile/user/phone_widget.dart` | 19 | avoid_catches_without_on_clauses |
                  MESSAGE

                  expect(flutter_lint.status_report[:errors].first).to eq(expected)
                end

                it 'should send 2 inline comment when inline mode is on & only modified files default to true' do
                  flutter_lint.lint(inline_mode: true)

                  errors = flutter_lint.status_report[:errors]

                  expected_errors = [
                    'Prefer const with constant constructors',
                    'AVOID catches without on clauses'
                  ]

                  expect(errors).to eq(expected_errors)
                end
              end

              context 'when report has no violations' do
                before do
                  allow(flutter_lint).to receive(:`)
                    .with('flutter analyze')
                    .and_return(File.read('spec/fixtures/flutter_analyze_without_violations.txt'))
                end

                it 'should NOT fail when lint' do
                  flutter_lint.lint

                  expect(flutter_lint.status_report[:errors]).to be_empty
                end

                it 'should add markdown message with 0 violations when inline mode is off and report on success is off' do
                  flutter_lint.lint(inline_mode: false)

                  expect(flutter_lint.status_report[:errors]).to eq([])
                end

                it 'should NOT print markdown message when inline mode is on' do
                  flutter_lint.lint(inline_mode: true)

                  markdown = flutter_lint.status_report[:errors]
                  expect(markdown).to be_empty
                end
              end
            end
          end
        end

        context 'when report path is set' do
          # Whether flutter is installed or not will not be relevant, as we prioritze report_path
          context 'when report path is from `flutter analyze`' do
            context 'when report has some violations' do
              before do
                flutter_lint.report_path = 'spec/fixtures/flutter_analyze_with_violations.txt'
                flutter_lint.warning_only = true
              end

              it 'should NOT fail when lint' do
                flutter_lint.lint

                expect(flutter_lint.status_report[:errors]).to be_empty
              end

              it 'should print markdown message with 3 violations when inline mode is off & only modified files set to false' do
                flutter_lint.only_modified_files = false
                flutter_lint.lint(inline_mode: false)

                expected = <<~MESSAGE
              ### Flutter Analyze found 3 issues ❌\n
              | File | Line | Rule |
              | ---- | ---- | ---- |
              | `lib/main.dart` | 5 | camel_case_types |
              | `lib/home/home_page.dart` | 13 | prefer_const_constructors |
              | `lib/profile/user/phone_widget.dart` | 19 | avoid_catches_without_on_clauses |
                MESSAGE

                expect(flutter_lint.status_report[:warnings].first).to eq(expected)
              end

              it 'should send 3 inline comment instead of markdown when inline mode is on & only modified files set to false' do
                flutter_lint.only_modified_files = false
                flutter_lint.lint(inline_mode: true)

                warnings = flutter_lint.status_report[:warnings]

                expected_warnings = [
                  'Name types using UpperCamelCase',
                  'Prefer const with constant constructors',
                  'AVOID catches without on clauses'
                ]

                expect(warnings).to eq(expected_warnings)
              end

              it 'should print markdown message with 2 violations when inline mode is off & only modified files default to true' do
                flutter_lint.lint(inline_mode: false)

                expected = <<~MESSAGE
              ### Flutter Analyze found 2 issues ❌\n
              | File | Line | Rule |
              | ---- | ---- | ---- |
              | `lib/home/home_page.dart` | 13 | prefer_const_constructors |
              | `lib/profile/user/phone_widget.dart` | 19 | avoid_catches_without_on_clauses |
                MESSAGE

                expect(flutter_lint.status_report[:warnings].first).to eq(expected)
              end

              it 'should send 2 inline comments when inline mode is on & only modified files set to true' do
                flutter_lint.only_modified_files = true
                flutter_lint.lint(inline_mode: true)

                warnings = flutter_lint.status_report[:warnings]

                expected_warnings = [
                  'Prefer const with constant constructors',
                  'AVOID catches without on clauses'
                ]
                expect(warnings).to eq(expected_warnings)
              end
            end

            context 'when report has no violations' do
              before do
                flutter_lint.report_path = 'spec/fixtures/flutter_analyze_without_violations.txt'
              end

              it 'should NOT fail when lint' do
                flutter_lint.lint

                expect(flutter_lint.status_report[:errors]).to be_empty
              end

              it 'should NOT print markdown message' do
                flutter_lint.lint(inline_mode: true)

                markdown = flutter_lint.status_report[:errors]
                expect(flutter_lint.status_report[:errors]).to eq([])
                expect(markdown).to be_empty
              end
            end
          end

          # Should be covered by report_path not set, flutter installed & modified_files set
          # context 'when report file is from `dart analyze modified files`' do
          #   context 'when report has some violations' do
          #     before do
          #       flutter_lint.report_path = 'spec/fixtures/dart_analyze_files_violations.txt'
          #     end
          #   end

          #   context 'when report has no violations' do
          #     before do
          #       flutter_lint.report_path = 'spec/fixtures/dart_analyze_files_no_violations.txt'
          #     end
          #   end
          # end

          context 'when report file is from `flutter analyze --write=report.txt`' do
            context 'when report has some violations' do
              before do
                flutter_lint.report_path = 'spec/fixtures/flutter_analyze_write_with_violations.txt'
              end

              it 'should print markdown message with 7 violations when inline mode is off' do
                flutter_lint.lint(inline_mode: false)

                expected = <<~MESSAGE
                ### Flutter Analyze found 7 issues ❌\n
                | File | Line | Rule |
                | ---- | ---- | ---- |
                | `integration_test/app_test.dart` | 11 | Avoid `print` calls in production code |
                | `integration_test/app_test.dart` | 4 | Duplicate import |
                | `lib/file.dart` | 9 | The declaration '_bar' isn't referenced |
                | `lib/file.dart` | 3 | The declaration '_bar' isn't referenced |
                | `lib/file.dart` | 9 | The name '_bar' is already defined |
                | `lib/file.dart` | 6 | The declaration '_foo' isn't referenced |
                | `lib/file.dart` | 10 | A function body must be provided |
                MESSAGE

                expect(flutter_lint.status_report[:errors].first).to eq(expected)
              end

              it 'should send 3 inline comments when inline mode is on filtered by block unchanged line' do
                changed_lines = {
                  'integration_test/app_test.dart': [{ number: 4 }, { number: 11 }, { number: 21 }],
                  'lib/file.dart': [{ number: 6 }]
                }
                flutter_lint.lint(inline_mode: true) do |violation|
                  changed_lines[:"#{violation.file}"].any? { |line| line[:number] == violation.line }
                end

                expected_errors = [
                  'Avoid `print` calls in production code',
                  'Duplicate import',
                  "The declaration '_foo' isn't referenced"
                ]
                expect(flutter_lint.status_report[:errors]).to eq(expected_errors)
              end
            end

            context 'when report has no violations' do
              before do
                flutter_lint.report_path = 'spec/fixtures/flutter_analyze_write_without_violations.txt'
              end

              it 'should NOT fail when lint' do
                flutter_lint.lint

                expect(flutter_lint.status_report[:errors]).to be_empty
              end

              context 'when report on success is on' do
                before do
                  flutter_lint.report_on_success = true
                end

                it 'should add markdown message with 0 violations when inline mode is off and report on success is on' do
                  flutter_lint.report_on_success = true
                  flutter_lint.lint(inline_mode: false)

                  expect(flutter_lint.status_report[:markdowns].first.message).to eq('### Flutter Analyze found 0 issues ✅')
                end
              end

              context 'when report on success is off' do
                before do
                  flutter_lint.report_on_success = false
                end

                it 'should NOT print markdown message when report on success is offf' do
                  flutter_lint.lint(inline_mode: false)

                  expect(flutter_lint.status_report[:errors]).to be_empty
                end
              end

              it 'should NOT print markdown message when inline mode is on' do
                flutter_lint.lint(inline_mode: true)

                markdown = flutter_lint.status_report[:errors]
                expect(markdown).to be_empty
              end
            end
          end
        end
      end
    end
  end
end
