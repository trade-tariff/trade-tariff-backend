class CdsImporter
  class EntityMapper
    class GeographicalAreaMembershipMapper < BaseMapper
      self.entity_class = 'GeographicalAreaMembership'.freeze

      self.mapping_root = 'GeographicalArea'.freeze

      self.mapping_path = 'geographicalAreaMembership'.freeze

      self.entity_mapping = base_mapping.merge(
        "#{mapping_path}.hjid" => :hjid,
        "#{mapping_path}.geographicalAreaGroupSid" => :geographical_area_group_sid,
        "#{mapping_path}.geographicalAreaSid" => :geographical_area_sid,
      ).freeze

      # This mutates misnamed attributes on geogrphical area memberships and coerces
      # them to be comprehensible to our importer.
      before_building_model do |xml_node|
        # Handle no membership XML node
        if xml_node['geographicalAreaMembership'].present?
          # Handle single membership XML node
          xml_node['geographicalAreaMembership'] = Array.wrap(xml_node['geographicalAreaMembership'])
          xml_node['geographicalAreaMembership'] = xml_node['geographicalAreaMembership'].each_with_object([]) do |geographical_area_membership, array|
            unless geographical_area_membership.key?('geographicalAreaGroupSid')
              message = "Skipping membership import due to missing geographical area group sid. hjid is #{geographical_area_membership['hjid']}\n"

              instrument_warning(message, xml_node)
              next
            end

            geographical_area = GeographicalArea[hjid: geographical_area_membership['geographicalAreaGroupSid']]

            geographical_area_membership['geographicalAreaSid'] = geographical_area&.geographical_area_sid
            geographical_area_membership['geographicalAreaGroupSid'] = xml_node['sid'].to_i

            array << geographical_area_membership
          end
        end
      end
    end
  end
end
