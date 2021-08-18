RSpec.describe Api::V2::Measures::MeasureLegalActSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) { Api::V2::Measures::MeasureLegalActPresenter.new(regulation, measure) }
  let(:regulation) { create(:base_regulation, base_regulation_id: '1234567') }
  let(:measure) { create(:measure) }

  let(:generated_url) do
    MeasureService::CouncilRegulationUrlGenerator.new(regulation).generate
  end

  let(:expected_pattern) do
    {
      'data' => {
        'id' => regulation.regulation_id.to_s,
        'type' => 'legal_act',
        'attributes' => {
          'validity_start_date' => regulation.validity_start_date,
          'validity_end_date' => regulation.validity_end_date,
          'officialjournal_number' => regulation.officialjournal_number,
          'officialjournal_page' => regulation.officialjournal_page,
          'regulation_code' => '14567/23',
          'regulation_url' => generated_url,
          'description' => regulation.information_text,
        },
      },
    }.as_json
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
