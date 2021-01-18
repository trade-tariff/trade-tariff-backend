#
# There is no collection with ExportRefundNomenclatureIndent in new xml.
# ExportRefundNomenclatureIndent is nested in to ExportRefundNomenclature.
# We will pass @values for ExportRefundNomenclatureIndent the same as for ExportRefundNomenclature.
#

class CdsImporter
  class EntityMapper
    class ExportRefundNomenclatureIndentMapper < BaseMapper
      self.entity_class = 'ExportRefundNomenclatureIndent'.freeze

      self.mapping_root = 'ExportRefundNomenclature'.freeze

      self.mapping_path = 'exportRefundNomenclatureIndents'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        "#{mapping_path}.sid" => :export_refund_nomenclature_indents_sid,
        'sid' => :export_refund_nomenclature_sid,
        "#{mapping_path}.numberExportRefundNomenclatureIndents" => :number_export_refund_nomenclature_indents,
        'goodsNomenclature.goodsNomenclatureItemId' => :goods_nomenclature_item_id,
        'additionalCodeType.additionalCodeTypeId' => :additional_code_type,
        'exportRefundCode' => :export_refund_code,
        'productLine' => :productline_suffix
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
