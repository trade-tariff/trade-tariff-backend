# Ugly but takes 20 - 30 seconds out the test suite run because it doesn't need
# to scan all the files only to then decide they are filtered out
unless RSpec.configuration.filter.opposite.rules[:roo_data]
  RSpec.describe 'Rules of Origin Data', :roo_data do
    describe 'v2 rulesets' do
      %w[uk xi].each do |service|
        RulesOfOrigin::SchemeSet::DEFAULT_SOURCE_PATH
          .join("roo_schemes_#{service}", 'rule_sets')
          .children
          .each do |data_set_json|
            next unless data_set_json.to_s.match? %r{\.json$}

            JSON.parse(data_set_json.read)['rule_sets'].each do |rule_set_data|
              context "with #{data_set_json.basename}" do
                subject(:rule_set) { RulesOfOrigin::V2::RuleSet.new(rule_set_data) }

                it %(is valid: '#{rule_set_data['heading']}'#{" - '#{rule_set_data['subdivision']}'" if rule_set_data['subdivision'].present?}) do
                  expect(rule_set).to be_valid
                end
              end
            end
          end
      end
    end

    describe 'UK articles' do
      RulesOfOrigin::SchemeSet::DEFAULT_SOURCE_PATH
        .join('roo_schemes_uk', 'articles')
        .children
        .select(&:directory?)
        .each do |country_folder|
          country_folder
          .children
          .select { |c| c.file? && c.extname == '.md' }
          .each do |file|
            context "for #{country_folder.basename}/#{file.basename}" do
              subject(:markdown) { File.read(file) }

              it 'has parseable numbered lists' do
                # Empty list entries are invalid markdown.
                # To fix, add a space after the period following the number
                # eg `5._`
                expect(markdown).not_to match(/^\d+\.$/m)
              end
            end
          end
        end
    end
  end
end
