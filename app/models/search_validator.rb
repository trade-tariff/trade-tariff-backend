class SearchValidator
  include ActiveModel::Model

  attr_accessor :type, :code, :description

  delegate :present?, to: :code, prefix: true
  delegate :present?, to: :type, prefix: true

  validates :type, presence: true, if: :code_present?
  validates :code, presence: true, if: :type_present?
  validates :description, presence: true, if: :code_and_type_blank?

  def code_and_type_blank?
    @code.blank? && @type.blank?
  end
end
