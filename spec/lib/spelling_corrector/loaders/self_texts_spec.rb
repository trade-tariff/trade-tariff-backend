RSpec.describe SpellingCorrector::Loaders::SelfTexts do
  describe '#load' do
    subject(:load) { described_class.new.load }

    before do
      create(:goods_nomenclature_self_text, self_text: 'Generated widgets widgetised cases')
      create(:goods_nomenclature_self_text, self_text: 'Generated expired terms', expired: true)
      create(:goods_nomenclature_self_text, self_text: 'EU 123 ab cases')
    end

    let(:expected_terms) do
      {
        'cases' => 2,
        'generated' => 1,
        'widgetised' => 1,
        'widgets' => 1,
      }
    end

    it { is_expected.to eq(expected_terms) }
  end
end
