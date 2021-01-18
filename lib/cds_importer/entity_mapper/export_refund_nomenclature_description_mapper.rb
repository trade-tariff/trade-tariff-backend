#
# There is no collection with ExportRefundNomenclatureDescription in new xml.
# ExportRefundNomenclatureDescription is nested in to ExportRefundNomenclatureDescriptionPeriod.
# We will pass @values for ExportRefundNomenclatureDescription the same as for ExportRefundNomenclature.
#

class CdsImporter
  class EntityMapper
    class ExportRefundNomenclatureDescriptionMapper < BaseMapper
      self.entity_class = 'ExportRefundNomenclatureDescription'.freeze

      self.mapping_root = 'ExportRefundNomenclature'.freeze

      self.mapping_path = 'exportRefundNomenclatureDescriptionPeriod.exportRefundNomenclatureDescription'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'exportRefundNomenclatureDescriptionPeriod.sid' => :export_refund_nomenclature_description_period_sid,
        "#{mapping_path}.language.languageId" => :language_id,
        'sid' => :export_refund_nomenclature_sid,
        'goodsNomenclature.goodsNomenclatureItemId' => :goods_nomenclature_item_id,
        'additionalCodeType.additionalCodeTypeId' => :additional_code_type,
        'exportRefundCode' => :export_refund_code,
        'productLine' => :productline_suffix,
        "#{mapping_path}.description" => :description
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
