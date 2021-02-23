require 'rails_helper'

describe CachedCommodityService do
  subject(:service) { described_class.new(commodity.reload, actual_date) }

  let(:actual_date) { Time.zone.today }

  let!(:commodity) do
    create(
      :commodity,
      :with_indent,
      :with_chapter,
      :with_heading,
      :with_description,
      :declarable,
    )
  end

  describe '#call' do
    let(:pattern) do
      {
        data: {
          id: String,
          type: 'commodity',
          attributes: Hash,
          relationships: {
            footnotes: Hash,
            section: Hash,
            chapter: Hash,
            heading: Hash,
            ancestors: Hash,
            import_measures: Hash,
            export_measures: Hash,
          },
        },
        included: [
          {
            id: String,
            type: 'chapter',
            attributes: Hash,
            relationships: {
              guides: Hash,
            },
          },
          {
            id: String,
            type: 'heading',
            attributes: Hash,
          },
          {
            id: String,
            type: 'section',
            attributes: Hash,
          },
        ],
      }
    end

    it 'returns a correctly serialized hash' do
      expect(service.call.to_json).to match_json_expression pattern
    end
  end
end
