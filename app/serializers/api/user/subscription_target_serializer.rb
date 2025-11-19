module Api
  module User
    class SubscriptionTargetSerializer
      include JSONAPI::Serializer

      set_type :subscription_target

      set_id :id

      attribute :target_type

      attribute :chapter_short_code do |sub_target|
        sub_target.commodity&.chapter_short_code
      end

      attribute :goods_nomenclature_item_id do |sub_target|
        sub_target.commodity&.goods_nomenclature_item_id
      end

      attribute :classification_description do |sub_target|
        sub_target.commodity&.classification_description
      end

      attribute :producline_suffix do |sub_target|
        sub_target.commodity&.producline_suffix
      end
    end
  end
end
