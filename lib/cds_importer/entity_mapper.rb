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
        remove_excluded_geographical_areas! if mapper == CdsImporter::EntityMapper::MeasureMapper

        transform! if mapper == CdsImporter::EntityMapper::GeographicalAreaMembershipMapper

        instances = mapper.new(xml_node).parse
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

    def remove_excluded_geographical_areas!
      if xml_node['sid'].blank?
        message = 'Skipping removal of measure geographical exclusions due to missing measure sid.'

        instrument_warning(message, xml_node)

        return
      end

      MeasureExcludedGeographicalArea.operation_klass.where(measure_sid: xml_node['sid']).delete
    end

    def transform!
      return unless xml_node.key?('geographicalAreaMembership')

      mutate_geographical_area_membership_node!
    end

    def mutate_geographical_area_membership_node!
      convert_single_geo_area_member_to_array!

      xml_node['geographicalAreaMembership'] = xml_node['geographicalAreaMembership'].each_with_object([]) do |geographical_area_membership, array|
        unless geographical_area_membership.key?('geographicalAreaGroupSid')
          message = "Skipping membership import due to missing geographical area group sid. hjid is #{geographical_area_membership['hjid']}\n"

          instrument_warning(message, xml_node)
          next
        end

        geographical_area = GeographicalArea[hjid: geographical_area_membership['geographicalAreaGroupSid']]

        geographical_area_membership['geographicalAreaSid'] = geographical_area&.geographical_area_sid
        geographical_area_membership['geographicalAreaGroupSid'] = geographical_area_group_sid.to_i

        array << geographical_area_membership
      end
    end

    def geographical_area_group_sid
      xml_node['sid']
    end

    def convert_single_geo_area_member_to_array!
      return if xml_node['geographicalAreaMembership'].is_a?(Array)

      xml_node['geographicalAreaMembership'] = [xml_node['geographicalAreaMembership']]
    end

    def instrument_warning(message, xml_node)
      instrument('apply.import_warnings', message: message, xml_node: xml_node)
    end

    def logger_enabled?
      TariffSynchronizer.cds_logger_enabled
    end
  end
end
