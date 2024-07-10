RSpec.describe Api::Admin::GreenLanes::CategoryAssessmentSerializer do
  subject do
    described_class.new(category,
                        params: { with_measures: true, with_exemptions: true, measure_pagination: measure_pagination },
                        include: %w[green_lanes_measures exemptions]).serializable_hash.as_json
  end

  let(:measure_pagination) {
    {
      current_page: 1,
      limit_value: 20,
      total_pages: 2
    }
  }
  let(:category) { create :category_assessment, :with_green_lanes_measure, :with_exemption }

  let :expected do
    {
      data: {
        id: category.id.to_s,
        type: 'category_assessment',
        attributes: {
          measure_type_id: category.measure_type_id,
          regulation_id: category.regulation_id,
          regulation_role: category.regulation_role,
          measure_pagination: {id: 1, type: 'measure_pagination', attributes: { current_page: 1, limit_value: 20, total_pages: 2 }},
        },
        relationships: {
          theme: {
            data: { id: category.theme_id.to_s, type: 'theme' },
          },
          green_lanes_measures: {
            data: [
              { id: /\A\d+\z/, type: 'green_lanes_measure' },
              { id: /\A\d+\z/, type: 'green_lanes_measure' },
            ],
          },
          exemptions: {
            data: [
              { id: /\A\d+\z/, type: 'green_lanes_exemption' },
              { id: /\A\d+\z/, type: 'green_lanes_exemption' },
            ],
          },
        },
      },
    }
  end

  it { is_expected.to include_json(expected) }
end
