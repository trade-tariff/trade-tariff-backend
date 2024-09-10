module Reporting
  class Differences
    class Loaders
      class QuotaMissingOrigin
        delegate :each_chapter,
                 to: :report

        include Reporting::Differences::Loaders::Helpers

        def data
          rows = []
          each_row do |row|
            rows << row
          end
          rows
        end

        private

        def each_row
          TimeMachine.at(report.as_of) do
            QuotaOrderNumber
              .actual
              .association_left_join(:quota_order_number_origins)
              .where(quota_order_numbers__quota_order_number_id: /^05/)
              .where(quota_order_number_origins__quota_order_number_origin_sid: nil)
              .select_map(
                %i[
                  quota_order_numbers__quota_order_number_id
                  quota_order_numbers__quota_order_number_sid
                  quota_order_numbers__validity_start_date
                  quota_order_numbers__validity_end_date
                ],
              ).each do |quota_order_number|
              yield build_row_for(quota_order_number)
            end
          end
        end

        def build_row_for(quota_order_number)
          validity_start_date = quota_order_number[2]&.to_date&.strftime('%d/%m/%Y')
          validity_end_date = quota_order_number[3]&.to_date&.strftime('%d/%m/%Y')

          [
            quota_order_number[0],
            quota_order_number[1],
            validity_start_date,
            validity_end_date,
          ]
        end
      end
    end
  end
end
