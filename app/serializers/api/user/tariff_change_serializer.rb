module Api
  module User
    class TariffChangeSerializer
      include JSONAPI::Serializer

      set_type :tariff_change

      set_id :id

      attributes :description, :goods_nomenclature_item_id
      attribute :date_of_effect do |tariff_change|
        tariff_change.date_of_effect.strftime('%d/%m/%Y')
      end
      attribute :classification_description do |tariff_change|
        TimeMachine.at(tariff_change.date_of_effect) do
          tariff_change.goods_nomenclature&.classification_description
        end
      end
    end
  end
end
