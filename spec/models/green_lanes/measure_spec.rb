RSpec.describe GreenLanes::Measure do
  before do
    TradeTariffRequest.time_machine_now = Time.current
  end

  describe 'attributes' do
    it { is_expected.to respond_to :id }
    it { is_expected.to respond_to :category_assessment_id }
    it { is_expected.to respond_to :goods_nomenclature_item_id }
    it { is_expected.to respond_to :productline_suffix }
    it { is_expected.to respond_to :created_at }
    it { is_expected.to respond_to :updated_at }
    it { is_expected.to respond_to :goods_nomenclature_sid }
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

      # rubocop:disable RSpec::EmptyExampleGroup
      context 'with expired goods_nomenclature' do
        before { gn.update(validity_end_date: 2.days.ago) }

        it_with_refresh_materialized_view 'returns nil' do
          expect(measure.goods_nomenclature).to be nil
        end
      end
      # rubocop:enable RSpec::EmptyExampleGroup
    end

    describe '#geographical_area' do
      subject { measure.geographical_area }

      before { erga_omnes }

      let(:erga_omnes) { create :geographical_area, :erga_omnes }
      let(:measure) { create :green_lanes_measure }

      it { is_expected.to eq_pk erga_omnes }

      context 'with eager loading' do
        subject do
          GoodsNomenclature.actual
                           .where(goods_nomenclature_item_id: measure.goods_nomenclature_item_id)
                           .eager(green_lanes_measures: :geographical_area)
                           .take
                           .green_lanes_measures
                           .map(&:geographical_area)
        end

        it { is_expected.to all eq_pk erga_omnes }
      end
    end
  end

  describe 'tariff measure emulation' do
    subject { gl_measure }

    let(:gl_measure) { create :green_lanes_measure, category_assessment: assessment }
    let(:assessment) { create :category_assessment }

    it { is_expected.to have_attributes measure_sid: /gl\d{6}/ }
    it { is_expected.to have_attributes measure_generating_regulation_id: assessment.regulation_id }
    it { is_expected.to have_attributes measure_generating_regulation_role: assessment.regulation_role }
    it { is_expected.to have_attributes generating_regulation: assessment.regulation }
    it { is_expected.to have_attributes geographical_area_id: GeographicalArea::ERGA_OMNES_ID }
    it { is_expected.to have_attributes goods_nomenclature_sid: gl_measure.goods_nomenclature.goods_nomenclature_sid }
    it { is_expected.to have_attributes measure_excluded_geographical_areas: [] }
    it { is_expected.to have_attributes excluded_geographical_areas: [] }
    it { is_expected.to have_attributes additional_code_id: nil }
    it { is_expected.to have_attributes additional_code_type_id: nil }
    it { is_expected.to have_attributes additional_code: nil }
    it { is_expected.to have_attributes measure_conditions: [] }
    it { is_expected.to have_attributes footnotes: [] }

    context 'with expired goods_nomenclature' do
      subject { gl_measure.reload }

      before { gl_measure.goods_nomenclature.update validity_end_date: 2.days.ago }

      it_with_refresh_materialized_view 'returns nil' do
        expect(gl_measure.reload).to have_attributes goods_nomenclature_sid: nil
      end
    end
  end
end
