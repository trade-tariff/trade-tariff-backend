RSpec.describe BaseRegulation do
  describe 'standardisation' do
    subject(:regulation) { build :base_regulation }

    it { is_expected.to have_attributes regulation_id: regulation.base_regulation_id }
    it { is_expected.to have_attributes role: regulation.base_regulation_role }
  end

  describe 'associations' do
    describe 'green_lanes_category_assessments' do
      subject { base_regulation.reload.green_lanes_category_assessments }

      before { category_assessment }

      let(:base_regulation) { create :base_regulation }
      let(:category_assessment) { create :category_assessment, base_regulation: }

      it { is_expected.to include category_assessment }

      context 'with for different regulation' do
        subject { create(:base_regulation).reload.green_lanes_category_assessments }

        it { is_expected.not_to include category_assessment }
      end
    end
  end
end
