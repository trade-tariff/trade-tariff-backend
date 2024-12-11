RSpec.describe GreenLanes::FaqFeedback do
  describe 'attributes' do
    it { is_expected.to respond_to :session_id }
    it { is_expected.to respond_to :category_id }
    it { is_expected.to respond_to :question_id }
    it { is_expected.to respond_to :useful }
  end

  describe 'validations' do
    subject(:errors) { instance.tap(&:valid?).errors }

    let(:instance) { described_class.new }

    it { is_expected.to include session_id: ['is not present'] }
    it { is_expected.to include category_id: ['is not present'] }
    it { is_expected.to include question_id: ['is not present'] }
    it { is_expected.to include useful: ['is not present'] }

    context 'with duplicate entry' do
      let(:session_id) { SecureRandom.uuid }
      let(:category_id) { 1 }
      let(:question_id) { 1 }

      before do
        create(:green_lanes_faq_feedback, session_id:, category_id:, question_id:)
      end

      it 'fails validation' do
        duplicate = build(:green_lanes_faq_feedback, session_id:, category_id:, question_id:)
        expect(duplicate.valid?).to be false
      end
    end
  end
end
