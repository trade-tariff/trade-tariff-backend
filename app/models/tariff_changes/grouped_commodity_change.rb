module TariffChanges
  class GroupedCommodityChange
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :id, :string
    attribute :description, :string
    attribute :count, :integer
    attribute :tariff_changes, default: -> { [] }

    def tariff_change_ids
      tariff_changes&.map(&:id)
    end
  end
end
