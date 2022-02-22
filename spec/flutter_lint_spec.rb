require File.expand_path('spec_helper', __dir__)

module Danger
  describe Danger::DangerFlutterLint do
    it 'should be a danger plugin' do
      expect(Danger::DangerFlutterLint.new(nil)).to be_a Danger::Plugin
    end

    describe 'with a Dangerfile' do
      before do
        @dangerfile = testing_dangerfile
        @flutter_lint = @dangerfile.flutter_lint
        @modified_files = [
          'lib/home/home_page.dart',
          'lib/profile/user/phone_widget.dart',
          'lib/file.dart',
          'integration_test/app_test.dart'
        ]
        allow(@flutter_lint.git).to receive(:deleted_files).and_return([])
        allow(@flutter_lint.git).to receive(:added_files).and_return([])
        allow(@flutter_lint.git).to receive(:modified_files).and_return(@modified_files)
      end

      context 'when report_path is not set or not exist' do
        context 'when flutter is not installed' do
          before do
            allow(@flutter_lint).to receive(:`).with('command -v flutter').and_return('')
          end

          it 'should fail when lint' do
            @flutter_lint.lint
            expect(@flutter_lint.status_report[:errors]).to eq(['Could not run lint without flutter and report file not found'])
          end
        end

        context 'when flutter is installed' do
          before do
            allow(@flutter_lint).to receive(:`).with('command -v flutter').and_return('/Users/johndoe/.flutter/bin/flutter')
          end

          context 'when modified files is set' do
            context 'when report has some violations' do
              before do
                allow(@flutter_lint).to receive(:`)
                                    .with("dart analyze #{@modified_files.join(' ')}")
                                    .and_return(File.read('spec/fixtures/dart_analyze_files_violations.txt'))
              end

              it 'should NOT fail when lint' do
                @flutter_lint.lint(@modified_files)

                expect(@flutter_lint.status_report[:errors]).to be_empty
              end

              it 'should print markdown message with 2 violations when inline mode is off' do
                @flutter_lint.lint(@modified_files, inline_mode: false)

                expected = <<~MESSAGE
                ### Flutter Analyze found 2 issues ❌\n
                | File | Line | Rule |
                | ---- | ---- | ---- |
                | `integration_test/app_test.dart` | 4 | duplicate_import |
                | `integration_test/app_test.dart` | 11 | avoid_print |
                MESSAGE

                expect(@flutter_lint.status_report[:markdowns].first.message).to eq(expected)
              end

              it 'should send 2 inline comment instead of markdown when inline mode is on' do
                @flutter_lint.lint(@modified_files, inline_mode: true)

                warnings = @flutter_lint.status_report[:warnings]

                expected_warnings = [
                  'Duplicate import. Try removing all but one import of the library.',
                  'Avoid `print` calls in production code.'
                ]

                expect(warnings).to eq(expected_warnings)
              end
            end

            context 'when report has no violations' do
              before do
                allow(@flutter_lint).to receive(:`)
                                    .with("dart analyze #{@modified_files.join(' ')}")
                                    .and_return(File.read('spec/fixtures/dart_analyze_files_no_violations.txt'))
              end

              it 'should NOT fail when lint' do
                @flutter_lint.lint(@modified_files)

                expect(@flutter_lint.status_report[:errors]).to be_empty
              end

              it 'should add markdown message with 0 violations when inline mode is off' do
                @flutter_lint.lint(@modified_files, inline_mode: false)

                markdown = @flutter_lint.status_report[:markdowns].first.message
                expect(markdown).to eq('### Flutter Analyze found 0 issues ✅')
              end

              it 'should NOT print markdown message when inline mode is on' do
                @flutter_lint.lint(@modified_files, inline_mode: true)

                markdown = @flutter_lint.status_report[:markdowns]
                expect(markdown).to be_empty
              end
            end
          end

          context 'when modified files is not set' do
            context 'when report has some violations' do
              before do
                allow(@flutter_lint).to receive(:`)
                                    .with('flutter analyze')
                                    .and_return(File.read('spec/fixtures/flutter_analyze_with_violations.txt'))
              end

              it 'should NOT fail when lint' do
                @flutter_lint.lint
  
                expect(@flutter_lint.status_report[:errors]).to be_empty
              end
  
              it 'should print markdown message with 3 violations when inline mode is off & only_modified_files set to false' do
                @flutter_lint.only_modified_files = false
                @flutter_lint.lint(inline_mode: false)
  
                expected = <<~MESSAGE
                ### Flutter Analyze found 3 issues ❌\n
                | File | Line | Rule |
                | ---- | ---- | ---- |
                | `lib/main.dart` | 5 | camel_case_types |
                | `lib/home/home_page.dart` | 13 | prefer_const_constructors |
                | `lib/profile/user/phone_widget.dart` | 19 | avoid_catches_without_on_clauses |
                MESSAGE
  
                expect(@flutter_lint.status_report[:markdowns].first.message).to eq(expected)
              end
  
              it 'should send 3 inline comment instead of markdown when inline mode is on & only_modified_files set to false' do
                @flutter_lint.only_modified_files = false
                @flutter_lint.lint(inline_mode: true)
  
                warnings = @flutter_lint.status_report[:warnings]
  
                expected_warnings = [
                  'Name types using UpperCamelCase', 
                  'Prefer const with constant constructors', 
                  'AVOID catches without on clauses'
                ]
  
                expect(warnings).to eq(expected_warnings)
              end
  
              it 'should print markdown message with 2 violations when inline mode is off & only_modified_files default to true' do
                @flutter_lint.lint(inline_mode: false)
  
                expected = <<~MESSAGE
                ### Flutter Analyze found 2 issues ❌\n
                | File | Line | Rule |
                | ---- | ---- | ---- |
                | `lib/home/home_page.dart` | 13 | prefer_const_constructors |
                | `lib/profile/user/phone_widget.dart` | 19 | avoid_catches_without_on_clauses |
                MESSAGE
  
                expect(@flutter_lint.status_report[:markdowns].first.message).to eq(expected)
              end
  
              it 'should send 2 inline comment instead of markdown when inline mode is on & only_modified_files default to true' do
                @flutter_lint.lint(inline_mode: true)
  
                warnings = @flutter_lint.status_report[:warnings]
  
                expected_warnings = [
                  'Prefer const with constant constructors', 
                  'AVOID catches without on clauses'
                ]
  
                expect(warnings).to eq(expected_warnings)
              end
            end

            context 'when report has no violations' do
              before do
                allow(@flutter_lint).to receive(:`)
                                    .with('flutter analyze')
                                    .and_return(File.read('spec/fixtures/flutter_analyze_without_violations.txt'))
              end

              it 'should NOT fail when lint' do
                @flutter_lint.lint
  
                expect(@flutter_lint.status_report[:errors]).to be_empty
              end
  
              it 'should add markdown message with 0 violations when inline mode is off' do
                @flutter_lint.lint(inline_mode: false)
  
                markdown = @flutter_lint.status_report[:markdowns].first.message
                expect(markdown).to eq('### Flutter Analyze found 0 issues ✅')
              end
  
              it 'should NOT print markdown message when inline mode is on' do
                @flutter_lint.lint(inline_mode: true)
  
                markdown = @flutter_lint.status_report[:markdowns]
                expect(markdown).to be_empty
              end
            end
          end
        end
      end

      context 'when report_path is set' do
        # Whether flutter is installed or not will not be relevant, as we prioritze report_path
        context 'when report path is from `flutter analyze`' do
          context 'when report has some violations' do
            before do
              @flutter_lint.report_path = 'spec/fixtures/flutter_analyze_with_violations.txt'
            end

            it 'should NOT fail when lint' do
              @flutter_lint.lint

              expect(@flutter_lint.status_report[:errors]).to be_empty
            end

            it 'should print markdown message with 3 violations when inline mode is off & only_modified_files set to false' do
              @flutter_lint.only_modified_files = false
              @flutter_lint.lint(inline_mode: false)

              expected = <<~MESSAGE
              ### Flutter Analyze found 3 issues ❌\n
              | File | Line | Rule |
              | ---- | ---- | ---- |
              | `lib/main.dart` | 5 | camel_case_types |
              | `lib/home/home_page.dart` | 13 | prefer_const_constructors |
              | `lib/profile/user/phone_widget.dart` | 19 | avoid_catches_without_on_clauses |
              MESSAGE

              expect(@flutter_lint.status_report[:markdowns].first.message).to eq(expected)
            end

            it 'should send 3 inline comment instead of markdown when inline mode is on & only_modified_files set to false' do
              @flutter_lint.only_modified_files = false
              @flutter_lint.lint(inline_mode: true)

              warnings = @flutter_lint.status_report[:warnings]

              expected_warnings = [
                'Name types using UpperCamelCase', 
                'Prefer const with constant constructors', 
                'AVOID catches without on clauses'
              ]

              expect(warnings).to eq(expected_warnings)
            end

            it 'should print markdown message with 2 violations when inline mode is off & only_modified_files default to true' do
              @flutter_lint.lint(inline_mode: false)

              expected = <<~MESSAGE
              ### Flutter Analyze found 2 issues ❌\n
              | File | Line | Rule |
              | ---- | ---- | ---- |
              | `lib/home/home_page.dart` | 13 | prefer_const_constructors |
              | `lib/profile/user/phone_widget.dart` | 19 | avoid_catches_without_on_clauses |
              MESSAGE

              expect(@flutter_lint.status_report[:markdowns].first.message).to eq(expected)
            end

            it 'should send 2 inline comment instead of markdown when inline mode is on & only_modified_files set to true' do
              @flutter_lint.only_modified_files = true
              @flutter_lint.lint(inline_mode: true)

              warnings = @flutter_lint.status_report[:warnings]

              expected_warnings = [
                'Prefer const with constant constructors', 
                'AVOID catches without on clauses'
              ]

              expect(warnings).to eq(expected_warnings)
            end
          end

          context 'when report has no violations' do
            before do
              @flutter_lint.report_path = 'spec/fixtures/flutter_analyze_without_violations.txt'
            end

            it 'should NOT fail when lint' do
              @flutter_lint.lint

              expect(@flutter_lint.status_report[:errors]).to be_empty
            end

            it 'should add markdown message with 0 violations when inline mode is off' do
              @flutter_lint.lint(inline_mode: false)

              markdown = @flutter_lint.status_report[:markdowns].first.message
              expect(markdown).to eq('### Flutter Analyze found 0 issues ✅')
            end

            it 'should NOT print markdown message when inline mode is on' do
              @flutter_lint.lint(inline_mode: true)

              markdown = @flutter_lint.status_report[:markdowns]
              expect(markdown).to be_empty
            end
          end
        end

        # Should be covered by report_path not set, flutter installed & modified_files set
        # context 'when report file is from `dart analyze modified_files`' do
        #   context 'when report has some violations' do
        #     before do
        #       @flutter_lint.report_path = 'spec/fixtures/dart_analyze_files_violations.txt'
        #     end
        #   end

        #   context 'when report has no violations' do
        #     before do
        #       @flutter_lint.report_path = 'spec/fixtures/dart_analyze_files_no_violations.txt'
        #     end
        #   end
        # end

        context 'when report file is from `flutter analyze --write=report.txt`' do
          context 'when report has some violations' do
            before do
              @flutter_lint.report_path = 'spec/fixtures/flutter_analyze_write_with_violations.txt'
            end

            it 'should NOT fail when lint' do
              @flutter_lint.lint

              expect(@flutter_lint.status_report[:errors]).to be_empty
            end

            it 'should print markdown message with 5 violations when inline mode is off' do
              @flutter_lint.lint(inline_mode: false)

              expected = <<~MESSAGE
              ### Flutter Analyze found 5 issues ❌\n
              | File | Line | Rule |
              | ---- | ---- | ---- |
              | `integration_test/app_test.dart` | 11 | Avoid `print` calls in production code  |
              | `integration_test/app_test.dart` | 4 | Duplicate import  |
              | `lib/file.dart` | 9 | The declaration '_bar' isn't referenced  |
              | `lib/file.dart` | 3 | The declaration '_bar' isn't referenced  |
              | `lib/file.dart` | 6 | The declaration '_foo' isn't referenced  |
              MESSAGE

              expect(@flutter_lint.status_report[:markdowns].first.message).to eq(expected)
            end
          end

          context 'when report has no violations' do
            before do
              @flutter_lint.report_path = 'spec/fixtures/flutter_analyze_write_without_violations.txt'
            end

            it 'should NOT fail when lint' do
              @flutter_lint.lint

              expect(@flutter_lint.status_report[:errors]).to be_empty
            end

            it 'should add markdown message with 0 violations when inline mode is off' do
              @flutter_lint.lint(inline_mode: false)

              markdown = @flutter_lint.status_report[:markdowns].first.message
              expect(markdown).to eq('### Flutter Analyze found 0 issues ✅')
            end

            it 'should NOT print markdown message when inline mode is on' do
              @flutter_lint.lint(inline_mode: true)

              markdown = @flutter_lint.status_report[:markdowns]
              expect(markdown).to be_empty
            end
          end
        end
      end
    end
  end
end
