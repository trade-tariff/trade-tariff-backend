class CdsImporter
  class ExcelWriter
    class QuotaDefinition < BaseMapper
      class << self
        def sheet_name
          'Quota definitions'
        end

        def note
          ['Please be careful when checking quota balances - each file may contains multiple updates on the same quota definition']
        end

        def table_span
          %w[A L]
        end

        def column_widths
          [30, 20, 50, 70, 20, 20, 20, 20, 20, 20, 20, 20]
        end

        def heading
          ['Action',
           'Quota order number',
           'Balance updates',
           'Sample commodities',
           'SID',
           'Critical state',
           'Critical threshold',
           'Initial volume',
           'Volume',
           'Maximum precision',
           'Start date',
           'End date']
        end

        def sort_columns
          [1]
        end

        def start_index
          3
        end

      end

      def data_row
        grouped = models.group_by { |model| model.class.name }
        quota_definition = grouped['QuotaDefinition'].first
        quota_balance_events = grouped['QuotaBalanceEvent']

        ["#{expand_operation(quota_definition)} definition",
         quota_definition.quota_order_number_id,
         quota_balance_event_string(quota_balance_events),
         comm_code_string(quota_definition.quota_definition_sid),
         quota_definition.quota_definition_sid,
         quota_definition.critical_state,
         quota_definition.critical_threshold,
         quota_definition.initial_volume,
         quota_definition.volume,
         quota_definition.maximum_precision,
         format_date(quota_definition.validity_start_date),
         format_date(quota_definition.validity_end_date)]
      end

      private

      def quota_balance_event_string(quota_balance_events)
        if quota_balance_events.blank?
          ''
        else
          quota_balance_events.sort_by!(&:occurrence_timestamp)
          last_event = quota_balance_events.last

          "#{format_date_ymd(last_event.occurrence_timestamp)} - New: #{last_event.new_balance} : Old: #{last_event.old_balance}"
        end
      end

      def comm_code_string(definition_id)
        definition = ::QuotaDefinition.where(quota_definition_sid: definition_id).eager(measures: []).first
        if definition.present?
          goods_nomenclature_item_ids = definition.measures.map(&:goods_nomenclature_item_id).uniq
          goods_nomenclature_item_ids.join(',')
        else
          ''
        end
      end
    end
  end
end
