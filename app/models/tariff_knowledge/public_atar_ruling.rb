module TariffKnowledge
  class PublicAtarRuling < Sequel::Model(:tariff_knowledge_public_atar_rulings)
    plugin :time_machine
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence
    plugin :validation_helpers
    skip_auto_validations(:not_null)

    dataset_module do
      def by_ref(ref)
        where(ref:)
      end
    end

    def validate
      super
      validates_presence %i[
        ref
        commodity_code
        goods_nomenclature_item_id
        description
        justification
        source_url
        raw_fields
        validity_start_date
        validity_end_date
        first_seen_at
        last_seen_at
        fetched_at
      ]
      validates_format(/\A\d{6}(?:\d{2}){0,2}\z/, :commodity_code) if commodity_code.present?
      validates_format(/\A\d{10}\z/, :goods_nomenclature_item_id) if goods_nomenclature_item_id.present?
      validates_unique :ref
      validate_normalized_codes
    end

    def validate_normalized_codes
      return if commodity_code.blank?

      errors.add(:goods_nomenclature_item_id, 'must match the normalized commodity code') if goods_nomenclature_item_id != commodity_code.ljust(10, '0')
    end
  end
end
