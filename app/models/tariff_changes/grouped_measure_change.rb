module TariffChanges
  class GroupedMeasureChange
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :id, :string
    attribute :trade_direction, :string
    attribute :count, :integer
    attribute :geographical_area_id, :string
    attribute :excluded_geographical_area_ids

    def geographical_area
      return nil unless geographical_area_id

      @geographical_area ||= GeographicalArea.find(geographical_area_id: geographical_area_id)
    end

    def excluded_geographical_areas
      return [] if excluded_geographical_area_ids.blank?

      ids = Array(excluded_geographical_area_ids).compact
      return [] if ids.empty?

      @excluded_geographical_areas ||= GeographicalArea.where(geographical_area_id: ids).all
    end
  end
end
