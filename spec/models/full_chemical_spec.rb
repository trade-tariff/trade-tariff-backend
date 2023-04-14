RSpec.describe FullChemical do
  it { is_expected.to have_many_to_one :goods_nomenclature }

  it { is_expected.to validate_presence_of(:goods_nomenclature_sid) }
  it { is_expected.to validate_presence_of(:goods_nomenclature_item_id) }
  it { is_expected.to validate_presence_of(:producline_suffix) }
  it { is_expected.to validate_presence_of(:name) }

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
