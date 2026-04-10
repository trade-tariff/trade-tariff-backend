class SectionNote < Sequel::Model
  plugin :json_serializer
  plugin :has_paper_trail

  many_to_one :section

  def validate
    super

    errors.add(:content, 'cannot be empty') if content.blank?
    errors.add(:section_id, 'cannot be empty') if section_id.blank?
  end
end
