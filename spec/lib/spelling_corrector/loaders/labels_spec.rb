RSpec.describe SpellingCorrector::Loaders::Labels do
  describe '#load' do
    subject(:load) { described_class.new.load }

    before do
      create(:goods_nomenclature_label,
             description: 'Generated label description',
             known_brands: Sequel.pg_array(['Acme Tools', 'Brand123'], :text),
             colloquial_terms: Sequel.pg_array(['widget case'], :text),
             synonyms: Sequel.pg_array(%w[gadget widget], :text))
      create(:goods_nomenclature_label,
             description: 'Expired label term',
             known_brands: Sequel.pg_array(['Expired Brand'], :text),
             expired: true)
    end

    let(:expected_terms) do
      {
        'acme' => 1,
        'case' => 1,
        'description' => 1,
        'gadget' => 1,
        'generated' => 1,
        'label' => 1,
        'tools' => 1,
        'widget' => 2,
      }
    end

    it { is_expected.to eq(expected_terms) }
  end
end
