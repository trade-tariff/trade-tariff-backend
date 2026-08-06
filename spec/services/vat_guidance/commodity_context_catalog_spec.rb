RSpec.describe VatGuidance::CommodityContextCatalog do
  subject(:contexts) { described_class.all }

  let(:expected_codes) do
    %w[
      2005202000
      2008939120
      2008979890
      8407100010
      8409100090
      8424100011
    ]
  end

  it 'contains the six Chapter 20 and Chapter 84 commodity contexts' do
    expect(contexts.pluck('commodity_code')).to match_array(expected_codes)
    expect(contexts.group_by { |context| context.fetch('chapter') }.transform_values(&:length)).to eq(
      '20' => 3,
      '84' => 3,
    )
  end

  it 'gives every commodity unique, section-addressed guidance evidence' do
    contexts.each do |context|
      evidence = context.fetch('evidence')

      expect(evidence).not_to be_empty
      expect(evidence).to eq(evidence.uniq)
      expect(evidence).to all(include('guide_key' => start_with('vat-notice-'), 'section_key' => be_present))
    end
  end

  it 'returns a copy that callers can safely modify' do
    contexts.first['label'] = 'Changed'

    expect(described_class.all.first.fetch('label')).to eq('Packaged potato crisps')
  end
end
