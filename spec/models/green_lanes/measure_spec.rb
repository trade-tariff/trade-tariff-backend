RSpec.describe GreenLanes::Measure do
  describe 'attributes' do
    it { is_expected.to respond_to :id }
    it { is_expected.to respond_to :category_assessment_id }
    it { is_expected.to respond_to :goods_nomenclature_item_id }
    it { is_expected.to respond_to :productline_suffix }
    it { is_expected.to respond_to :created_at }
    it { is_expected.to respond_to :updated_at }
  end

  describe 'validations' do
    subject(:errors) { instance.tap(&:valid?).errors }

    let(:instance) { described_class.new }

    it { is_expected.to include category_assessment_id: ['is not present'] }
    it { is_expected.to include goods_nomenclature_item_id: ['is not present'] }
    it { is_expected.to include productline_suffix: ['is not present'] }

    context 'with duplicate associations' do
      let(:existing) { create :green_lanes_measure }

      let :instance do
        build :green_lanes_measure,
              category_assessment_id: existing.category_assessment_id,
              goods_nomenclature_item_id: existing.goods_nomenclature_item_id,
              productline_suffix: existing.productline_suffix
      end

      let :uniqueness_key do
        %i[category_assessment_id goods_nomenclature_item_id productline_suffix]
      end

      it { is_expected.to include uniqueness_key => ['is already taken'] }
    end
  end

  describe 'associations' do
    describe '#category_assessment' do
      subject { measure.category_assessment }

      let(:measure) { create :green_lanes_measure, category_assessment_id: ca.id }
      let(:ca) { create :category_assessment }

      it { is_expected.to be_instance_of GreenLanes::CategoryAssessment }
    end

    describe '#goods_nomenclature' do
      subject { measure.goods_nomenclature }

      let :measure do
        create :green_lanes_measure,
               goods_nomenclature_item_id: gn.goods_nomenclature_item_id,
               productline_suffix: gn.producline_suffix
      end

      let(:gn) { create :commodity }

      it { is_expected.to be_instance_of Commodity }
    end
  end
end
