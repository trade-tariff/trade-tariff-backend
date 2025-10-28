class CdsImporter
  class ExcelWriter
    class GeographicalArea < BaseMapper
      class << self
        def sheet_name
          'Geographical areas'
        end

        def table_span
          %w[A I]
        end

        def column_widths
          [30, 20, 15, 15, 20, 50, 70, 70, 15]
        end

        def heading
          ['Action',
           'Geographical area ID',
           'SID',
           'Start date',
           'End date',
           'Description(s)',
           'Current memberships',
           'All memberships',
           'Parent group SID']
        end

        def sort_columns
          [1]
        end
      end

      def data_row
        grouped = models.group_by { |model| model.class.name }
        geo_area = grouped['GeographicalArea'].first
        geo_area_description_periods = grouped['GeographicalAreaDescriptionPeriod']
        geo_area_descriptions = grouped['GeographicalAreaDescription']
        geo_area_memberships = grouped['GeographicalAreaMembership']

        ["#{expand_operation(geo_area)} geographical area",
         geo_area.geographical_area_id,
         geo_area.geographical_area_sid,
         format_date(geo_area.validity_start_date),
         format_date(geo_area.validity_end_date),
         periodic_description(geo_area_description_periods, geo_area_descriptions, &method(:period_matches?)),
         current_membership_string(geo_area_memberships),
         membership_string(geo_area_memberships),
         geo_area.parent_geographical_area_group_sid]
      end

      private

      def geographical_area(geo_area_sid)
        ga = ::GeographicalArea
               .where(geographical_area_sid: geo_area_sid)
               .eager(:geographical_area_descriptions).first

        if ga
          ga.description
        else
          "#{geo_area_sid} not found. Is this an expired geographical area?"
        end
      end

      def membership_string(geographical_area_memberships)
        return '' unless geographical_area_memberships&.any?

        geographical_area_memberships.map { |membership|
          if membership.validity_end_date.to_s.strip.empty?
            "#{format_date(membership.validity_start_date)} : #{geographical_area(membership.geographical_area_group_sid)}\n"
          else
            "#{format_date(membership.validity_start_date)} to #{format_date(membership.validity_end_date)} : #{geographical_area(membership.geographical_area_group_sid)}\n"
          end
        }.join
      end

      def current_membership_string(geographical_area_memberships)
        return '' unless geographical_area_memberships&.any?

        geographical_area_memberships.each do |membership|
          if membership.validity_end_date.to_s.strip.empty?
            return "#{format_date(membership.validity_start_date)} : #{geographical_area(membership.geographical_area_group_sid)}\n"
          end
        end
        ''
      end

      def period_matches?(period, description)
        period.geographical_area_description_period_sid == description.geographical_area_description_period_sid &&
          period.geographical_area_sid == description.geographical_area_sid &&
          period.geographical_area_id == description.geographical_area_id
      end
    end
  end
end
