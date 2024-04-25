RSpec.describe GreenLanes::Exemption do
  describe 'attributes' do
    it { is_expected.to respond_to :id }
    it { is_expected.to respond_to :code }
    it { is_expected.to respond_to :description }
    it { is_expected.to respond_to :created_at }
    it { is_expected.to respond_to :updated_at }
  end

  describe 'validations' do
    subject(:errors) { instance.tap(&:valid?).errors }

    let(:instance) { described_class.new }

    it { is_expected.to include code: ['is not present'] }
    it { is_expected.to include description: ['is not present'] }

    context 'with duplicate code' do
      let(:existing) { create :green_lanes_exemption }
      let(:instance) { build :green_lanes_exemption, code: existing.code }

      it { is_expected.to include code: ['is already taken'] }
    end
  end

  describe '#associations' do
    describe '#category_assessments' do
      subject { exemption.reload.category_assessments }

      let :exemption do
        create(:green_lanes_exemption).tap do |exempt|
          exempt.add_category_assessment create(:category_assessment)
        end
      end

      it { is_expected.to include instance_of GreenLanes::CategoryAssessment }
    end

    describe '#category_assessments_pks' do
      subject { exemption.reload.category_assessment_pks }

      let :exemption do
        create(:green_lanes_exemption).tap do |exempt|
          exempt.category_assessment_pks = assessments.map(&:pk)
          exempt.save
        end
      end

      let(:assessments) { create_list :category_assessment, 1 }

      it { is_expected.to match_array assessments.map(&:id) }
    end
  end
end
