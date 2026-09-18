# frozen_string_literal: true

module SearchAnalytics
  # One compact row for each service, UTC date and hashed journey.
  # Built from search_journeys and journey_outcomes JSON. all_hours, classic_hours
  # and internal_hours are bitmaps of UTC hours when that view saw the journey.
  # terminal packs the latest outcome time and kind. flags mark selected, zero
  # result, questions and unknown. This is the grain used to find repeats and to
  # roll up journeys that stay on a single date.
  class DailyJourney < Sequel::Model(:search_analytics_daily_journeys)
    include MaterializedView

    set_primary_key %i[service reporting_date journey_key]
  end
end
