RSpec.describe Api::V2::GreenLanes::CategoryAssessmentSerializer do
  subject(:serialized) do
    described_class.new(
      ::GreenLanes::CategoryAssessment.load_from_string(json_string), include: %i[exemptions]
    ).serializable_hash.as_json
  end

  let(:json_string) do
    [{
      'category' => '1',
      'regulation_id' => 'D0000001',
      'measure_type_id' => '400',
      'geographical_area' => '1000',
      'theme' => '1.1 Sanctions',
      'document_codes' => %w[Y123],
      'additional_codes' => %w[B456],
    }].to_json
  end

  let(:expected_pattern) do
    {
      data: [
        id: be_a(String),
        type: 'green_lanes_category_assessment',
        attributes: {
          category: '1',
          geographical_area: '1000',
          excluded_geographical_areas: [],
          theme: '1.1 Sanctions',
          document_codes: %w[Y123],
          additional_codes: %w[B456],
        },
        relationships: {
          exemptions: {
            data: [
              { id: 'Y123', type: 'certificate' },
              { id: '1', type: 'additional_code' },
            ],
          },
        },
      ],
      included: [
        {
          id: 'Y123',
          type: 'certificate',
          attributes: {
            certificate_type_code: 'Y',
            certificate_code: '123',
            description: be_a(String),
            formatted_description: be_a(String),
          },
        },
        {
          id: '1',
          type: 'additional_code',
          attributes: {
            code: 'B456',
            description: be_a(String),
            formatted_description: be_a(String),
          },
        },
      ],
    }
  end

  before do
    create(:certificate, :with_description, certificate_type_code: 'Y', certificate_code: '123')
    create(:additional_code, :with_description, additional_code_type_id: 'B', additional_code: '456')
  end

  it { expect(serialized).to include_json(expected_pattern) }
end
