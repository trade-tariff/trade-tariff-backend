RSpec.describe Api::V2::RulesOfOrigin::SchemeSerializer do
  subject { serializer.serializable_hash }

  let(:scheme_set) { build :rules_of_origin_scheme_set, links: [], schemes: [] }

  let :scheme do
    build :rules_of_origin_scheme,
          :with_links,
          :with_origin_reference_document,
          scheme_set:,
          unilateral: true
  end

  let :serializer do
    described_class.new \
      Api::V2::RulesOfOrigin::SchemePresenter.new(scheme, [], []),
      include: %i[links origin_reference_document]
  end

  let :expected do
    {
      data: {
        id: scheme.scheme_code,
        type: :rules_of_origin_scheme,
        attributes: {
          scheme_code: scheme.scheme_code,
          title: scheme.title,
          countries: scheme.countries,
          unilateral: true,
          proof_intro: nil,
          proof_codes: {},
        },
        relationships: {
          links: {
            data: [
              {
                id: scheme.links[0].id,
                type: :rules_of_origin_link,
              },
              {
                id: scheme.links[1].id,
                type: :rules_of_origin_link,
              },
            ],
          },
          origin_reference_document: {
            data: {
              id: scheme.origin_reference_document.id,
              type: :rules_of_origin_origin_reference_document,
            },
          },
          proofs: { data: [] },
          rule_sets: { data: [] },
        },
      },
      included: [
        {
          id: scheme.links[0].id,
          type: :rules_of_origin_link,
          attributes: {
            text: scheme.links[0].text,
            url: scheme.links[0].url,
            source: scheme.links[0].source,
          },
        },
        {
          id: scheme.links[1].id,
          type: :rules_of_origin_link,
          attributes: {
            text: scheme.links[1].text,
            url: scheme.links[1].url,
            source: scheme.links[1].source,
          },
        },
        {
          id: scheme.origin_reference_document.id,
          type: :rules_of_origin_origin_reference_document,
          attributes: {
            ord_date: scheme.origin_reference_document.ord_date,
            ord_original: scheme.origin_reference_document.ord_original,
            ord_title: scheme.origin_reference_document.ord_title,
            ord_version: scheme.origin_reference_document.ord_version,
          },
        },
      ],
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to eql expected }
  end
end
