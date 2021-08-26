namespace :rules_of_origin do
  desc 'validate a CSV rules of origin file - CSVFILE=path/to/file.csv'
  task validate_rules: :environment do
    if ENV['CSVFILE'].blank?
      raise ArgumentError, 'Missing CSVFILE environment variable'
    end

    invalid_rules = RulesOfOrigin::RuleSet.new(ENV['CSVFILE']).tap(&:import).invalid_rules

    if invalid_rules.empty?
      puts " ✅  Success: #{ENV['CSVFILE']} is valid"
    else
      puts " ❌  FAILURE: #{ENV['CSVFILE']} is invalid"
      puts '=' * 60

      invalid_rules.each do |invalid_rule|
        id_rule = sprintf('%12d', invalid_rule.id_rule)
        puts "#{id_rule}: #{invalid_rule.errors.full_messages.to_sentence}"
      end
    end
  end
end
