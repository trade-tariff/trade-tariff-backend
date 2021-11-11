class CdsImporter
  class EntityMapper
    ALL_MAPPERS = CdsImporter::EntityMapper::BaseMapper.descendants.freeze

    delegate :instrument, to: ActiveSupport::Notifications

    attr_reader :xml_node, :key

    def initialize(key, xml_node)
      @key = key
      @xml_node = xml_node
      @filename = xml_node.delete('filename')
    end

    def import
      # select all mappers that have mapping_root equal to current xml key
      # it means that every selected mapper requires fetched by this xml key
      # sort mappers to apply top level first
      # e.g. Footnote before FootnoteDescription
      mappers = ALL_MAPPERS.select  { |m| m.mapping_root == key }
                           .sort_by { |m| m.mapping_path ? m.mapping_path.length : 0 }

      mappers.each.with_object({}) do |mapper, oplog_inserts_performed|
        instances = mapper.new(xml_node).parse

        mapper.before_oplog_inserts_callbacks.each { |callback| callback.call(xml_node) }

        instances.each do |i|
          oplog_inserts_performed[i.operation_klass.to_s] ||= 0

          oplog_oid = logger_enabled? ? save_record(i) : save_record!(i)

          oplog_inserts_performed[i.operation_klass.to_s] += 1 if oplog_oid
        end
      end
    end

    private

    def save_record!(record)
      values = record.values.except(:oid)

      values.merge!(filename: @filename)

      operation_klass = record.class.operation_klass

      if operation_klass.columns.include?(:created_at)
        values.merge!(created_at: operation_klass.dataset.current_datetime)
      end

      operation_klass.insert(values)
    end

    def save_record(record)
      save_record!(record)
    rescue StandardError => e
      instrument('cds_error.cds_importer', record: record, xml_key: key, xml_node: xml_node, exception: e)
      nil
    end

    def instrument_warning(message, xml_node)
      instrument('apply.import_warnings', message: message, xml_node: xml_node)
    end

    def logger_enabled?
      TariffSynchronizer.cds_logger_enabled
    end
  end
end
