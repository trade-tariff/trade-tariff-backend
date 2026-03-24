module Api
  module User
    class ActiveCommoditiesReportService
      ACTIVE = 'Active'.freeze
      EXPIRED = 'Expired'.freeze
      ERROR_FROM_UPLOAD = 'Error from upload'.freeze
      NOT_APPLICABLE = 'Not applicable'.freeze

      def self.call(active_codes, expired_codes, invalid_codes)
        new(active_codes, expired_codes, invalid_codes).call
      end

      def initialize(active_codes, expired_codes, invalid_codes)
        @active_codes = normalize_codes(active_codes)
        @expired_codes = normalize_codes(expired_codes)
        @invalid_codes = normalize_codes(invalid_codes)
      end

      def call
        package = Axlsx::Package.new
        package.use_shared_strings = true

        ActiveCommoditiesReportWorksheetBuilder.call(
          workbook: package.workbook,
          report_rows: report_rows,
        )

        package
      end

      private

      attr_reader :active_codes, :expired_codes, :invalid_codes

      def normalize_codes(codes)
        codes.to_a.map(&:to_s).uniq
      end

      def report_rows
        @report_rows ||= begin
          all_codes = (active_codes + expired_codes + invalid_codes).uniq.sort
          valid_codes = all_codes - invalid_codes
          descriptions = load_classification_descriptions(valid_codes)
          load_chapter_names(valid_codes)
          statuses = status_by_code

          all_codes.map do |code|
            status = statuses[code]

            {
              code: code,
              chapter: chapter_display_value(code, status),
              description: description_display_value(code, descriptions, status),
              status: status,
            }
          end
        end
      end

      def status_by_code
        @status_by_code ||= {}.tap do |statuses|
          active_codes.each { |code| statuses[code] = ACTIVE }
          expired_codes.each { |code| statuses[code] ||= EXPIRED }
          invalid_codes.each { |code| statuses[code] ||= ERROR_FROM_UPLOAD }
        end
      end

      def description_display_value(code, descriptions, status)
        return NOT_APPLICABLE if status == ERROR_FROM_UPLOAD

        descriptions.fetch(code, {})
      end

      def chapter_number_for(code)
        normalized_code = code.to_s
        return unless normalized_code.match?(/\A\d{10}\z/)

        normalized_code[0, 2]
      end

      def chapter_display_value(code, status)
        return NOT_APPLICABLE if status == ERROR_FROM_UPLOAD

        chapter_number = chapter_number_for(code)
        return '' if chapter_number.blank?

        formatted_chapter_number = chapter_number.to_s.rjust(2, '0')
        chapter_name = chapter_names[chapter_number].to_s
        "#{formatted_chapter_number}: #{chapter_name}".strip
      end

      def chapter_names
        @chapter_names ||= {}
      end

      def load_chapter_names(codes)
        chapter_codes_by_number = codes.each_with_object({}) do |code, result|
          chapter_number = chapter_number_for(code)
          next if chapter_number.blank?

          result[chapter_number] = "#{chapter_number}00000000"
        end

        return chapter_names if chapter_codes_by_number.empty?

        chapter_descriptions = Chapter.actual
          .where(goods_nomenclature_item_id: chapter_codes_by_number.values)
          .eager(:goods_nomenclature_descriptions)
          .all
          .each_with_object({}) do |chapter, descriptions|
            descriptions[chapter.goods_nomenclature_item_id] = chapter.formatted_description.to_s
          end

        @chapter_names = chapter_codes_by_number.transform_values do |chapter_code|
          chapter_descriptions[chapter_code].to_s
        end
      end

      def load_classification_descriptions(codes)
        CachedCommodityDescriptionService.fetch_for_codes(codes, include_hierarchy: true)
      end
    end
  end
end
