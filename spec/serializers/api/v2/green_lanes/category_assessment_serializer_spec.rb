RSpec.describe Api::V2::GreenLanes::CategoryAssessmentSerializer do
  subject(:serialized) do
    described_class.new(
      category_assessment,
      include: %w[exemptions geographical_area excluded_geographical_areas],
    ).serializable_hash.as_json
  end

  before do
    create(:geographical_area, :with_reference_group_and_members, :with_description)
    create(:certificate, :with_description, certificate_type_code: 'Y', certificate_code: '123')
    create(:additional_code, :with_description, additional_code_type_id: 'B', additional_code: '456')
  end

  let(:category_assessment) do
    build :category_assessment_json, regulation_id: 'D0000001',
                                     measure_type_id: '400',
                                     geographical_area_id: 'EU',
                                     document_codes: %w[Y123],
                                     additional_codes: %w[B456],
                                     theme: '1.1 Sanctions'
  end

  let(:expected_pattern) do
    {
      data: {
        id: be_a(String),
        type: 'category_assessment',
        attributes: {
          category: 1,
          theme: '1.1 Sanctions',
        },
        relationships: {
          exemptions: {
            data: [
              { id: 'Y123', type: 'certificate' },
              { id: '1', type: 'additional_code' },
            ],
          },
          "geographical_area": {
            "data": {
              "id": 'EU',
              "type": 'geographical_area',
            },
          },
          "excluded_geographical_areas": {
            "data": [],
          },
        },
      },
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
        {
          "id": 'EU',
          "type": 'geographical_area',
          "attributes": {
            "id": 'EU',
            "description": 'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.',
            "geographical_area_id": 'EU',
            "geographical_area_sid": 1,
          },
        },
      ],
    }
  end

  it { is_expected.to include_json(expected_pattern) }
end
