RSpec.describe FullChemical do
  describe '#goods_nomenclature' do
    subject(:goods_nomenclature) { create(:full_chemical).goods_nomenclature }

    it { is_expected.to be_a(GoodsNomenclature) }
  end

  describe 'validations' do
    subject(:errors) { described_class.new.tap(&:valid?).errors }

    it { is_expected.to include(goods_nomenclature_sid: ['is not present']) }
    it { is_expected.to include(goods_nomenclature_item_id: ['is not present']) }
    it { is_expected.to include(producline_suffix: ['is not present']) }
    it { is_expected.to include(name: ['is not present']) }
  end

  describe 'dataset methods' do
    describe '.by_code' do
      let!(:full_chemical) { create(:full_chemical, goods_nomenclature_item_id: '0409000000') }

      it 'returns the correct full chemical' do
        expect(described_class.by_code('0409000000').take).to eq(full_chemical)
      end
    end

    describe '.by_suffix' do
      let!(:full_chemical) { create(:full_chemical, producline_suffix: '80') }

      it 'returns the correct full chemical' do
        expect(described_class.by_suffix('80').take).to eq(full_chemical)
      end
    end

    describe '.by_cus' do
      let!(:full_chemical) { create(:full_chemical, cus: '0154438-3') }

      it 'returns the correct full chemical' do
        expect(described_class.by_cus('0154438-3').take).to eq(full_chemical)
      end
    end

    describe '.by_cas_rn' do
      let!(:full_chemical) { create(:full_chemical, cas_rn: '8028-66-8') }

      it 'returns the correct full chemical' do
        expect(described_class.by_cas_rn('8028-66-8').take).to eq(full_chemical)
      end
    end
  end
end
