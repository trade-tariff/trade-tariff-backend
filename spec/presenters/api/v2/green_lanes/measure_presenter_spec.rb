RSpec.describe Api::V2::GreenLanes::MeasurePresenter do
  subject(:presented) { described_class.new(measure) }

  let :measure do
    create :measure, :with_footnote_association, :with_goods_nomenclature, :with_base_regulation
  end

  let(:footnotes) { measure.footnotes }

  it { is_expected.to have_attributes id: measure.measure_sid }
  it { is_expected.to have_attributes footnotes: }
  it { is_expected.to have_attributes footnote_ids: footnotes.map(&:code) }
  it { is_expected.to have_attributes goods_nomenclature_id: measure.goods_nomenclature.goods_nomenclature_sid }

  describe '#generating_regulation' do
    subject { presented.generating_regulation }

    it { is_expected.to be_instance_of Api::V2::GreenLanes::RegulationPresenter }
  end
end
