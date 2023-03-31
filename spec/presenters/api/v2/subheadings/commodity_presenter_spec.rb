RSpec.describe Api::V2::Subheadings::CommodityPresenter do
  subject(:presenter) { described_class.new commodity }

  let(:commodity) { create :commodity }

  it { is_expected.to have_attributes goods_nomenclature_sid: commodity.goods_nomenclature_sid }

  context 'with tree' do
    let(:child) { create :commodity, parent: commodity }

    context 'for declarable' do
      subject { described_class.new child }

      it { is_expected.to have_attributes declarable: true }
      it { is_expected.to have_attributes leaf: true }
      it { is_expected.to have_attributes number_indents: 2 }
    end

    context 'for non_declarable' do
      subject { described_class.new child.ns_parent }

      it { is_expected.to have_attributes declarable: false }
      it { is_expected.to have_attributes leaf: false }
      it { is_expected.to have_attributes number_indents: 1 }
    end
  end

  describe '#parent_sid' do
    context 'with highest commodity in tree' do
      it { is_expected.to have_attributes parent_sid: nil }
    end

    context 'with lower commodities in tree' do
      subject { described_class.new child }

      let(:child) { create :commodity, parent: commodity }

      it { is_expected.to have_attributes parent_sid: commodity.pk }
    end
  end

  describe '#wrap' do
    subject { described_class.wrap [commodity, second_commodity] }

    let(:second_commodity) { create :commodity }

    it { is_expected.to all be_instance_of described_class }
  end

  describe '#overview_measures' do
    before { measures }

    let(:commodity) { create :commodity, :with_chapter_and_heading }

    let(:measures) do
      [
        Api::V2::Measures::MeasurePresenter.new(heading_measure, commodity.ns_parent),
        Api::V2::Measures::MeasurePresenter.new(measure, commodity),
      ]
    end

    let :measure do
      create :measure, :with_base_regulation, :supplementary, goods_nomenclature: commodity
    end

    let :heading_measure do
      create :measure, :with_base_regulation, :supplementary, goods_nomenclature: commodity.ns_parent
    end

    it 'has expected measures' do
      expect(presenter.overview_measures).to eq_pk measures
    end

    it 'wraps the measures' do
      expect(presenter.overview_measures).to all \
        be_instance_of(Api::V2::Measures::MeasurePresenter)
    end

    it { is_expected.to have_attributes overview_measure_ids: measures.map(&:measure_sid) }
  end
end
