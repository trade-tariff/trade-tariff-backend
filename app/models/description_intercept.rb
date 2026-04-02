class DescriptionIntercept < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence
  plugin :has_paper_trail

  def validate
    super
    validates_presence :term
    validates_presence :sources
    validates_includes [true, false], :excluded

    if Array(sources).empty?
      errors.add(:sources, 'is not present')
    end
  end
end
