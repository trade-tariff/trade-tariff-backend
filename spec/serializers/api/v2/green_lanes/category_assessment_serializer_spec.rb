RSpec.describe Api::V2::GreenLanes::CategoryAssessmentSerializer do
  subject(:serialized) do
    described_class.new(
      presented,
      params: {},
      include: %w[theme exemptions geographical_area excluded_geographical_areas],
    ).serializable_hash.as_json
  end

  before { category_assessment.add_exemption exemption }

  let(:category_assessment) { create :category_assessment, measure: }
  let(:certificate) { create :certificate, :exemption, :with_certificate_type, :with_description }
  let(:measure) { create :measure, :with_additional_code, :with_base_regulation, certificate: }
  let(:exemption) { create :green_lanes_exemption }

  let :presented do
    Api::V2::GreenLanes::CategoryAssessmentPresenter.wrap(category_assessment).first
  end

  let(:expected_pattern) do
    {
      data: {
        id: be_a(String),
        type: 'category_assessment',
        relationships: {
          theme: {
            data: { id: category_assessment.theme.code, type: 'theme' },
          },
          exemptions: {
            data: [
              { id: certificate.id, type: 'certificate' },
              { id: measure.additional_code.id.to_s, type: 'additional_code' },
              { id: exemption.code, type: 'exemption' },
            ],
          },
          geographical_area: {
            data: {
              id: measure.geographical_area_id,
              type: 'geographical_area',
            },
          },
          excluded_geographical_areas: {
            data: [],
          },
          measure_type: {
            data: { id: category_assessment.measure_type_id, type: 'measure_type' },
          },
          regulation: {
            data: { id: category_assessment.regulation_id, type: 'legal_act' },
          },
        },
      },
      included: [
        {
          id: category_assessment.theme.code,
          type: 'theme',
          attributes: {
            section: category_assessment.theme.code,
            theme: category_assessment.theme.description,
            category: category_assessment.theme.category,
          },
        },
        {
          id: certificate.id,
          type: 'certificate',
          attributes: {
            certificate_type_code: certificate.certificate_type_code,
            certificate_code: certificate.certificate_code,
            description: be_a(String),
            formatted_description: be_a(String),
          },
        },
        {
          id: '1',
          type: 'additional_code',
          attributes: {
            code: measure.additional_code.code,
            description: be_a(String),
            formatted_description: be_a(String),
          },
        },
        {
          id: exemption.code,
          type: 'exemption',
          attributes: {
            code: exemption.code,
            description: be_a(String),
            formatted_description: be_a(String),
          },
        },
        {
          id: measure.geographical_area_id,
          type: 'geographical_area',
          attributes: {
            id: measure.geographical_area_id,
            description: /\w+/,
            geographical_area_id: measure.geographical_area_id,
            geographical_area_sid: measure.geographical_area_sid,
          },
        },
      ],
    }
  end

  it { is_expected.to include_json(expected_pattern) }

  describe 'measures relationship' do
    context 'with measures' do
      subject do
        described_class.new(presented, params: { with_measures: true })
                       .serializable_hash
                       .as_json['data']['relationships']
      end

      it { is_expected.to include 'measures' }
    end

    context 'with green lanes measures' do
      subject(:relationships) do
        described_class.new(presented, params: { with_measures: true })
                       .serializable_hash
                       .as_json['data']['relationships']
      end

      before { create :green_lanes_measure, category_assessment: }

      let(:category_assessment) { create :category_assessment }

      it { is_expected.to include 'measures' }
      it { expect(relationships['measures']['data'].pluck('id')).to include %r{gl\d+} }
    end

    context 'without measures' do
      subject { serialized['data']['relationships'] }

      it { is_expected.not_to include 'measures' }
    end
  end
end
