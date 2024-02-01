RSpec.describe Api::V2::GreenLanes::CategoryAssessmentSerializer do
  subject(:serialized) do
    described_class.new(::GreenLanes::CategoryAssessment.load_from_string(json_string)).serializable_hash.as_json
  end

  let(:json_string) do
    [{
      'category' => '1',
      'regulation_id' => 'D0000001',
      'measure_type_id' => '400',
      'geographical_area' => '1000',
      'document_codes' => [],
      'additional_codes' => [],
    }].to_json
  end

  let(:expected_pattern) do
    {
      data: [
        id: be_a(String),
        type: 'green_lanes_category_assessment',
        attributes: {
          category: '1',
          regulation_id: 'D0000001',
          measure_type_id: '400',
          geographical_area: '1000',
          document_codes: [],
          additional_codes: [],
        },
      ],
    }
  end

  it { is_expected.to include_json(expected_pattern) }
end
