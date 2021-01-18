class CdsImporter
  class EntityMapper
    class GeographicalAreaMembershipMapper < BaseMapper
      self.entity_class = "GeographicalAreaMembership".freeze

      self.mapping_root = "GeographicalArea".freeze

      self.mapping_path = "geographicalAreaMembership".freeze

      self.entity_mapping = base_mapping.merge(
        "#{mapping_path}.hjid" => :hjid,
        "#{mapping_path}.geographicalAreaGroupSid" => :geographical_area_group_sid,
        "#{mapping_path}.geographicalAreaSid" => :geographical_area_sid
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
