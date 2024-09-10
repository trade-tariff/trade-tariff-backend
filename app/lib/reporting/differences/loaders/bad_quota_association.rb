module Reporting
  class Differences
    class Loaders
      class BadQuotaAssociation
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
          ::BadQuotaAssociation.actual.each do |bad_quota_association|
            yield build_row_for(bad_quota_association)
          end
        end

        def build_row_for(bad_quota_association)
          validity_start_date = bad_quota_association.validity_start_date.strftime('%d/%m/%Y')
          validity_end_date = bad_quota_association.validity_end_date.strftime('%d/%m/%Y')
          [
            bad_quota_association.main_quota_order_number_id,
            validity_start_date,
            validity_end_date,
            bad_quota_association.main_origin,
            bad_quota_association.sub_quota_order_number_id,
            validity_start_date,
            validity_end_date,
            bad_quota_association.sub_origin,
            bad_quota_association.relation_type,
            bad_quota_association.coefficient,
          ]
        end
      end
    end
  end
end
