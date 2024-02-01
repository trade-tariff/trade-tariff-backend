RSpec.describe Api::V2::GreenLanes::GoodsNomenclaturePresenter do
  subject(:presenter) { described_class.new(gn, GreenLanes::Categorisation.load_from_string(json_string)) }

  let(:gn) { create :goods_nomenclature, :with_measures }
  let(:json_string) do
    '[{
          "category": "1",
          "regulation_id": "D0000001",
          "measure_type_id": "400",
          "geographical_area": "1000",
          "document_codes": [],
          "additional_codes": []
        }]'
  end

  it { is_expected.to have_attributes goods_nomenclature_sid: gn.goods_nomenclature_sid }

  it 'includes applicable measures ids' do
    expect(presenter.applicable_measure_ids).to eq gn.applicable_measures.map(&:id)
  end

  it 'includes possible categorisation ids' do
    expect(presenter.possible_categorisation_ids).to eq [GreenLanes::Categorisation.all[0].id]
  end

  describe '#applicable_measures' do
    subject(:applicable_measures) { presenter.applicable_measures }

    it { is_expected.to all(be_an(Api::V2::Measures::MeasurePresenter)) }

    it { expect(applicable_measures.first.id).to eq(gn.applicable_measures.first.id) }
  end

  describe '#possible_categorisations' do
    subject(:possible_categorisations) { presenter.possible_categorisations }

    it { is_expected.to all(be_an(GreenLanes::Categorisation)) }

    it { expect(possible_categorisations.first.id).to eq(GreenLanes::Categorisation.all[0].id) }
  end
end
