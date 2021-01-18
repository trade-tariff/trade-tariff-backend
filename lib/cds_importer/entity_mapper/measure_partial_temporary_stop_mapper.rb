#
# MeasurePartialTemporaryStop is nested in to Measure.
#

class CdsImporter
  class EntityMapper
    class MeasurePartialTemporaryStopMapper < BaseMapper
      self.entity_class = 'MeasurePartialTemporaryStop'.freeze

      self.mapping_path = 'measurePartialTemporaryStop'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :measure_sid,
        "#{mapping_path}.partialTemporaryStopRegulationId" => :partial_temporary_stop_regulation_id,
        "#{mapping_path}.partialTemporaryStopRegulationOfficialjournalNumber" => :partial_temporary_stop_regulation_officialjournal_number,
        "#{mapping_path}.partialTemporaryStopRegulationOfficialjournalPage" => :partial_temporary_stop_regulation_officialjournal_page,
        "#{mapping_path}.abrogationRegulationId" => :abrogation_regulation_id,
        "#{mapping_path}.abrogationRegulationOfficialjournalNumber" => :abrogation_regulation_officialjournal_number,
        "#{mapping_path}.abrogationRegulationOfficialjournalPage" => :abrogation_regulation_officialjournal_page
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
