RSpec.describe FaqFeedback do
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

  describe '.statistics' do
    subject(:statistics) { described_class.statistics }

    before do
      create(:green_lanes_faq_feedback, category_id: 1, question_id: 1, useful: true)
      create(:green_lanes_faq_feedback, category_id: 1, question_id: 1, useful: false)
      create(:green_lanes_faq_feedback, category_id: 1, question_id: 2, useful: true)
      create(:green_lanes_faq_feedback, category_id: 2, question_id: 1, useful: false)
    end

    it 'returns the correct statistics grouped by category and question' do
      expect(statistics).to contain_exactly(
        include(category_id: 1, question_id: 1, useful_count: 1, not_useful_count: 1),
        include(category_id: 1, question_id: 2, useful_count: 1, not_useful_count: 0),
        include(category_id: 2, question_id: 1, useful_count: 0, not_useful_count: 1),
      )
    end
  end
end
