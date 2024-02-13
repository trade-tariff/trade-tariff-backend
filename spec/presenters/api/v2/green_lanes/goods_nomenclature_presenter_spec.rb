RSpec.describe Api::V2::GreenLanes::GoodsNomenclaturePresenter do
  subject(:presenter) { described_class.new(gn, GreenLanes::CategoryAssessment.load_from_string(json_string)) }

  let(:gn) { create :goods_nomenclature, :with_measures }
  let(:json_string) do
    '[{
          "category": "1",
          "regulation_id": "D0000001",
          "measure_type_id": "400",
          "geographical_area_id": "1000",
          "document_codes": [],
          "additional_codes": []
        }]'
  end

  it { is_expected.to have_attributes goods_nomenclature_sid: gn.goods_nomenclature_sid }

  it 'includes applicable category assessment ids' do
    expect(presenter.applicable_category_assessment_ids).to eq [GreenLanes::CategoryAssessment.all[0].id]
  end

  describe '#applicable_category_assessments' do
    subject(:applicable_category_assessments) { presenter.applicable_category_assessments }

    it { is_expected.to all(be_an(GreenLanes::CategoryAssessment)) }

    it { expect(applicable_category_assessments.first.id).to eq(GreenLanes::CategoryAssessment.all[0].id) }
  end
end
