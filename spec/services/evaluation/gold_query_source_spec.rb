RSpec.describe Evaluation::GoldQuerySource do
  def create_commodity_description(item_id:, text:, period_sid: 1)
    gn = create(:goods_nomenclature, goods_nomenclature_item_id: item_id, validity_start_date: 3.years.ago)
    create(
      :goods_nomenclature_description,
      goods_nomenclature_sid: gn.goods_nomenclature_sid,
      goods_nomenclature_item_id: item_id,
      goods_nomenclature_description_period_sid: period_sid,
      description: text,
      validity_start_date: 1.year.ago,
      validity_end_date: nil,
    )
  end

  describe '.from_public_atar_ruling' do
    subject(:source) { described_class.from_public_atar_ruling(ruling) }

    let(:ruling) do
      create(
        :tariff_knowledge_public_atar_ruling,
        ref: '600014988',
        commodity_code: '6302100000',
        goods_nomenclature_item_id: '6302100000',
        description: 'Bed linen woven from cotton fabric.',
        justification: 'Classified in accordance with GIR 1.',
      )
    end

    before { create_commodity_description(item_id: '6302100000', text: 'Bed linen, of cotton') }

    it 'describes the ruling' do
      expect(source).to have_attributes(
        source_type: 'atar',
        source_id: '600014988',
        text: 'Bed linen woven from cotton fabric.',
        oracle_text: 'Bed linen woven from cotton fabric.',
        real_user_search: nil,
        expected_code: '6302100000',
        expected_description: 'Bed linen, of cotton',
      )
    end

    context 'when the description is blank' do
      # Built, not saved: the model refuses a blank description, but the builder only reads the values.
      let(:ruling) { build(:tariff_knowledge_public_atar_ruling, ref: '600014988', description: '', justification: 'Classified in accordance with GIR 1.') }

      it 'falls back to the justification for the text and the oracle text' do
        expect(source).to have_attributes(text: 'Classified in accordance with GIR 1.', oracle_text: 'Classified in accordance with GIR 1.')
      end
    end

    context 'when the ruling only classified to 8 digits' do
      let(:ruling) { create(:tariff_knowledge_public_atar_ruling, ref: '600014988', commodity_code: '63021000') }

      it 'keeps the published code and never pads it to a 10 digit leaf' do
        expect(source.expected_code).to eq('63021000')
        expect(ruling.goods_nomenclature_item_id).to eq('6302100000')
      end
    end

    context 'when the code has no commodity description' do
      let(:ruling) { create(:tariff_knowledge_public_atar_ruling, ref: '600014989', commodity_code: '9999999999', goods_nomenclature_item_id: '9999999999') }

      it 'has no expected description (nil, not an empty string)' do
        expect(source.expected_description).to be_nil
      end
    end

    context 'when the code has several description periods' do
      before { create_commodity_description(item_id: '6302100000', text: 'A newer description', period_sid: 2) }

      it 'uses the newest period' do
        expect(source.expected_description).to eq('A newer description')
      end
    end
  end

  describe '.from_synthetic_atar' do
    subject(:source) { described_class.from_synthetic_atar(synthetic_atar) }

    let(:synthetic_atar) do
      create(
        :tariff_knowledge_synthetic_atar,
        real_user_search: 'lunch box',
        description: 'Plastic lunch box with a lid, for carrying food.',
        goods_nomenclature_item_id: '3924100000',
      )
    end

    before { create_commodity_description(item_id: '3924100000', text: 'Tableware of plastics') }

    it 'describes the synthetic ATaR, with its id as a string and its real search' do
      expect(source).to have_attributes(
        source_type: 'synthetic_atar',
        source_id: synthetic_atar.id.to_s,
        text: 'Plastic lunch box with a lid, for carrying food.',
        oracle_text: 'Plastic lunch box with a lid, for carrying food.',
        real_user_search: 'lunch box',
        expected_code: '3924100000',
        expected_description: 'Tableware of plastics',
      )
    end
  end

  describe '.for' do
    it 'finds an ATaR from its ref' do
      create(:tariff_knowledge_public_atar_ruling, ref: '600014988')

      expect(described_class.for(source_type: 'atar', source_id: '600014988')).to have_attributes(source_type: 'atar', source_id: '600014988')
    end

    it 'finds a synthetic ATaR from its id given as a string' do
      synthetic_atar = create(:tariff_knowledge_synthetic_atar)

      expect(described_class.for(source_type: 'synthetic_atar', source_id: synthetic_atar.id.to_s))
        .to have_attributes(source_type: 'synthetic_atar', source_id: synthetic_atar.id.to_s)
    end

    it 'returns nil when the ATaR no longer exists' do
      expect(described_class.for(source_type: 'atar', source_id: '000000000')).to be_nil
    end

    it 'returns nil when the synthetic ATaR no longer exists' do
      expect(described_class.for(source_type: 'synthetic_atar', source_id: '999999')).to be_nil
    end

    it 'returns nil for an unknown source type' do
      expect(described_class.for(source_type: 'made_up', source_id: '1')).to be_nil
    end
  end
end
