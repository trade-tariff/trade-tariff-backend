module Reporting
  class Differences
    class Loaders
      module Helpers
        delegate :uk_goods_nomenclatures,
                 :xi_goods_nomenclatures,
                 to: :report

        def initialize(report)
          @report = report
        end

        attr_reader :report

        def get
          local_data = data
          save_difference_log(key, local_data)
          check_for_new_records(key, local_data)
        end

        def key
          self.class.name
        end

        def save_difference_log(key, value)
          purge_difference_log(key)
          DifferencesLog.create(date: Time.zone.today, key:, value: value.to_json)
        end

        def purge_difference_log(key)
          DifferencesLog.where(key:, date: Time.zone.today).delete
        end

        def check_for_new_records(key, value)
          previous_data_json = DifferencesLog.where(key:).exclude(date: Time.zone.today).order(Sequel.desc(:date)).first
          return value unless previous_data_json

          previous_data = JSON.parse(previous_data_json.value)
          value.each do |row|
            match = previous_data.find { |previous_row| previous_row[0] == row[0] }
            row << (match.nil? ? 'Yes' : 'No')
          end
          value
        end
      end
    end
  end
end
