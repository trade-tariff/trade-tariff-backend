RSpec.describe ModificationRegulation do
  describe 'standardisation' do
    subject(:regulation) { build :modification_regulation }

    it { is_expected.to have_attributes regulation_id: regulation.modification_regulation_id }
    it { is_expected.to have_attributes role: regulation.modification_regulation_role }
  end

  describe 'associations' do
    describe 'green_lanes_category_assessments' do
      subject { modification_regulation.reload.green_lanes_category_assessments }

      before { category_assessment }

      let(:modification_regulation) { create :modification_regulation }
      let(:category_assessment) { create :category_assessment, modification_regulation: }

      it { is_expected.to include category_assessment }

      context 'with for different regulation' do
        subject { create(:modification_regulation).reload.green_lanes_category_assessments }

        it { is_expected.not_to include category_assessment }
      end
    end
  end
end
