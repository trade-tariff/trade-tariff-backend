RSpec.describe SimplifiedProceduralCode do
  describe '#to_null_measure' do
    subject(:to_null_measure) { simplified_procedural_code.to_null_measure }

    let(:simplified_procedural_code) do
      create(
        :simplified_procedural_code,
        simplified_procedural_code: '2.130.0',
      )
    end

    it { is_expected.to be_a SimplifiedProceduralCodeMeasure }
    it { expect(to_null_measure.simplified_procedural_code).to eq simplified_procedural_code.simplified_procedural_code }
    it { expect(to_null_measure.goods_nomenclature_item_ids).to eq '0808108010, 0808108020, 0808108090' }
    it { expect(to_null_measure.goods_nomenclature_label).to eq simplified_procedural_code.goods_nomenclature_label }
  end

  describe '.all_null_measures' do
    subject(:all_null_measures) { described_class.all_null_measures }

    before do
      create(:simplified_procedural_code, simplified_procedural_code: '2.130.0')
      create(:simplified_procedural_code, simplified_procedural_code: '2.150')
    end

    it { is_expected.to all(be_a(SimplifiedProceduralCodeMeasure)) }
    it { expect(all_null_measures.count).to eq 2 }
    it { expect(all_null_measures.map(&:simplified_procedural_code)).to contain_exactly('2.130.0', '2.150') }
    it { expect(all_null_measures.map(&:goods_nomenclature_item_ids)).to contain_exactly('0808108010, 0808108020, 0808108090', '0809100000') }
    it { expect(all_null_measures.map(&:goods_nomenclature_label)).to all(be_present) }
  end

  describe '.populate' do
    subject(:populate) { described_class.populate }

    it { expect { populate }.to change(described_class, :count).by(53) }
  end

  describe '.codes' do
    subject(:codes) { described_class.codes }

    it { is_expected.to be_a Hash }
    it { expect(codes.keys).to all(be_a String) }
    it { expect(codes.values).to all(be_a Hash) }
    it { expect(codes.values.map { |v| v['label'] }).to all(be_a String) }
    it { expect(codes.values.map { |v| v['commodities'] }).to all(be_an Array) }
    it { expect(codes.values.map { |v| v['commodities'].first }).to all(be_a String) }
  end
end
