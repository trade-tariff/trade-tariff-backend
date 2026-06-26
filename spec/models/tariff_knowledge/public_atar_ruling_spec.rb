RSpec.describe TariffKnowledge::PublicAtarRuling do
  describe 'validations' do
    it 'requires a ruling reference and extracted content' do
      ruling = described_class.new

      expect(ruling).not_to be_valid
      expect(ruling.errors.keys).to include(
        :ref,
        :commodity_code,
        :goods_nomenclature_item_id,
        :description,
        :justification,
        :source_url,
        :raw_fields,
        :validity_start_date,
        :validity_end_date,
        :first_seen_at,
        :last_seen_at,
        :fetched_at,
      )
    end

    it 'allows rulings with no extracted keywords' do
      ruling = build(:tariff_knowledge_public_atar_ruling, keywords: [])

      expect(ruling).to be_valid
    end

    it 'validates normalized commodity association keys' do
      ruling = build(
        :tariff_knowledge_public_atar_ruling,
        commodity_code: '85371095',
        goods_nomenclature_item_id: '8537109501',
      )

      expect(ruling).not_to be_valid
      expect(ruling.errors.full_messages).to include(
        'goods_nomenclature_item_id must match the normalized commodity code',
      )
    end
  end

  describe 'database constraints' do
    it 'enforces one row per ruling reference' do
      create(:tariff_knowledge_public_atar_ruling, ref: '600015804')
      duplicate = build(:tariff_knowledge_public_atar_ruling, ref: '600015804')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors.full_messages).to include('ref is already taken')
    end
  end

  describe '.actual' do
    it 'filters rulings using TimeMachine point in time' do
      current = create(
        :tariff_knowledge_public_atar_ruling,
        ref: '600015804',
        validity_start_date: Date.new(2026, 6, 26),
        validity_end_date: Date.new(2029, 6, 25),
      )
      create(
        :tariff_knowledge_public_atar_ruling,
        ref: '600004365',
        validity_start_date: Date.new(2023, 11, 21),
        validity_end_date: Date.new(2026, 6, 25),
      )

      TimeMachine.at(Date.new(2026, 6, 26)) do
        expect(described_class.actual.all).to contain_exactly(current)
      end
    end
  end
end
