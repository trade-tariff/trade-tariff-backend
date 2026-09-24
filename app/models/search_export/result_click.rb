# frozen_string_literal: true

module SearchExport
  class ResultClick < Sequel::Model(:search_export_result_clicks)
    def self.record(request_id:, commodity_code:, result_rank:, clicked_at: Time.current)
      code = commodity_code.to_s[/\A\d{10}\z/]
      rank = Integer(result_rank)
      return if request_id.blank? || code.nil? || !rank.between?(0, 100)

      create(request_id:, commodity_code: code, result_rank: rank, clicked_at:)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
