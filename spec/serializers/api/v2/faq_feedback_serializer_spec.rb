RSpec.describe Api::V2::FaqFeedbackSerializer do
  subject(:serialized) do
    described_class.new(faq_feedback).serializable_hash
  end

  let(:faq_feedback) { create :green_lanes_faq_feedback }

  let :expected do
    {
      data: {
        id: faq_feedback.id.to_s,
        type: :green_lanes_faq_feedback,
        attributes: {
          session_id: faq_feedback.session_id,
          category_id: faq_feedback.category_id,
          question_id: faq_feedback.question_id,
          useful: faq_feedback.useful,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serialized).to eq(expected)
    end
  end
end
