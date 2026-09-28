module TariffKnowledge
  # A product description written by HMRC analysts, starting from a real search
  # typed by an Online Trade Tariff user. It works like a small ATaR: a
  # description plus the correct commodity code. Evaluation gold queries are
  # generated from these records. It deliberately lives outside the Evaluation
  # namespace because it is HMRC reference data that the Knowledge Graph may use.
  #
  # A record is identified by its real user search, trimmed and compared without
  # regard to case (unique index on lower(real_user_search)).
  class SyntheticAtar < Sequel::Model(:tariff_knowledge_synthetic_atars)
    CHAPTER_FORMAT = /\A\d{2}\z/
    CODE_FORMAT = /\A\d{10}\z/
    OPTIONAL_TEXT_COLUMNS = %i[likely_heading notes completed_by].freeze

    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence
    plugin :validation_helpers
    plugin :has_paper_trail
    skip_auto_validations(:not_null)
    # The format validations below already reject a value that is too long.
    # Without this the operator would see two messages for the same mistake.
    skip_auto_validations(:max_length)

    # A blank optional value is stored as nil at the moment it is assigned. If "" were
    # assigned to a column that is already NULL, Sequel would count that as a change,
    # and setting it back to nil later does not undo that. Re-saving unchanged data
    # (for example importing the same spreadsheet twice) would then write a new version.
    OPTIONAL_TEXT_COLUMNS.each do |column|
      define_method(:"#{column}=") { |value| super(value.presence) }
    end

    dataset_module do
      def search(query)
        return self if query.blank?

        where(
          Sequel.ilike(:real_user_search, "%#{query}%") |
            Sequel.ilike(:description, "%#{query}%"),
        )
      end

      def for_chapter(chapter)
        return self if chapter.blank?

        where(chapter: chapter.to_s.strip.rjust(2, '0'))
      end

      def by_real_user_search(value)
        where(Sequel.function(:lower, :real_user_search) => value.to_s.squish.downcase)
      end
    end

    def before_validation
      self.real_user_search = real_user_search.squish if real_user_search
      self.chapter = chapter.strip.rjust(2, '0') if chapter&.strip&.match?(/\A\d\z/)
      self.goods_nomenclature_item_id = goods_nomenclature_item_id.strip if goods_nomenclature_item_id

      super
    end

    def validate
      super
      validates_presence %i[chapter real_user_search description goods_nomenclature_item_id]
      validates_format(CHAPTER_FORMAT, :chapter, message: 'must be a two digit chapter, for example 01') if chapter.present?
      if goods_nomenclature_item_id.present?
        validates_format(
          CODE_FORMAT,
          :goods_nomenclature_item_id,
          message: 'must be exactly 10 digits (check that a leading zero has not been dropped)',
        )
      end
      validate_unique_real_user_search
    end

  private

    def validate_unique_real_user_search
      return if real_user_search.blank?

      conflict = self.class.by_real_user_search(real_user_search)
      conflict = conflict.exclude(id:) if id
      errors.add(:real_user_search, 'is already used by another synthetic ATaR') if conflict.any?
    end
  end
end
