module Api
  module V3
    class FootnoteSerializer
      def initialize(footnote)
        @footnote = footnote
      end

      def call
        {
          footnote_type_id: @footnote.footnote_type_id,
          footnote_id: @footnote.footnote_id,
          description: @footnote.description,
          validity_start_date: @footnote.validity_start_date,
          validity_end_date: @footnote.validity_end_date,
        }
      end

      def self.collection(footnotes)
        list = footnotes.map { |f| new(f).call }
        { data: list, meta: { total: list.size } }
      end

      def self.type_collection(footnote_types)
        list = footnote_types.map do |ft|
          {
            footnote_type_id: ft.footnote_type_id,
            description: ft.description,
            application_code: ft.application_code,
            validity_start_date: ft.validity_start_date,
            validity_end_date: ft.validity_end_date,
          }
        end
        { data: list, meta: { total: list.size } }
      end
    end
  end
end
