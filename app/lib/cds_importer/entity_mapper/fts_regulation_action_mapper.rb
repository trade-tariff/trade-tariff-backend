#
# There is no collection with FtsRegulationAction in new xml.
# FtsRegulationAction is nested in to FullTemporaryStopRegulation.
# We will pass @values for FtsRegulationAction the same as for FullTemporaryStopRegulation
#

class CdsImporter
  class EntityMapper
    class FtsRegulationActionMapper < BaseMapper
      self.entity_class = 'FtsRegulationAction'.freeze

      self.mapping_root = 'FullTemporaryStopRegulation'.freeze

      self.mapping_path = 'ftsRegulationAction'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'regulationRoleType.regulationRoleTypeId' => :fts_regulation_role,
        'fullTemporaryStopRegulationId' => :fts_regulation_id,
        "#{mapping_path}.stoppedRegulationRole" => :stopped_regulation_role,
        "#{mapping_path}.stoppedRegulationId" => :stopped_regulation_id
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
