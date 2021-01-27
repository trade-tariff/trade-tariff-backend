module Clearable
  extend ActiveSupport::Concern

  included do
    def self.clear_association_cache
      association_reflections.map do |_association, association_state|
        association_state[:cache] = {} if association_state[:cache].present?
      end
    end
  end
end

Sequel::Model.include Clearable
