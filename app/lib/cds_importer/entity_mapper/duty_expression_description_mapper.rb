#
# There is no collection with DutyExpressionDescription in new xml.
# DutyExpressionDescription is nested in to DutyExpression.
# We will pass @values for DutyExpressionDescription the same as for DutyExpression
#

class CdsImporter
  class EntityMapper
    class DutyExpressionDescriptionMapper < BaseMapper
      self.entity_class = 'DutyExpressionDescription'.freeze

      self.mapping_root = 'DutyExpression'.freeze

      self.mapping_path = 'dutyExpressionDescription'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate', 'metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'dutyExpressionId' => :duty_expression_id,
        "#{mapping_path}.language.languageId" => :language_id,
        "#{mapping_path}.description" => :description,
      ).freeze
    end
  end
end
