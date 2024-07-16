RSpec.describe GreenLanes::FindCategoryAssessmentsService do
  describe '#call' do
    subject :presented_assessments do
      described_class.call(goods_nomenclature.applicable_measures, geographical_area_id)
                     .group_by(&:category_assessment_id)
    end

    before { category_assessments }

    let(:goods_nomenclature) { create(:subheading) }
    let(:category_assessments) { measures.map { |m| create :category_assessment, measure: m } }
    let(:geographical_area_id) { nil }

    let :measures do
      create_list(:measure, 2, :with_base_regulation,
                  goods_nomenclature:,
                  for_geo_area: countries[:switzerland]) +
        create_list(:measure, 1, :with_base_regulation,
                    goods_nomenclature:,
                    for_geo_area: countries[:erga_omnes])
    end

    let :countries do
      switzerland = create(:geographical_area, geographical_area_id: 'CH')
      france = create(:geographical_area, geographical_area_id: 'FR')
      erga_omnes = create(:geographical_area, :erga_omnes, members: [switzerland, france])

      { erga_omnes:, switzerland:, france: }
    end

    context 'without origin filter' do
      it { is_expected.to have_attributes length: 3 }

      context 'for swiss assessment' do
        subject { presented_assessments[category_assessments[0].id].first }

        it { is_expected.to have_attributes measure_ids: [measures[0].measure_sid] }
      end

      context 'for erga omnes assessment' do
        subject { presented_assessments[category_assessments[2].id].first }

        it { is_expected.to have_attributes measure_ids: [measures[2].measure_sid] }
      end
    end

    context 'when origin is matches measure countries' do
      let(:geographical_area_id) { countries[:switzerland].geographical_area_id }

      it { is_expected.to have_attributes length: 3 }

      context 'for swiss assessment' do
        subject { presented_assessments[category_assessments[0].id].first }

        it { is_expected.to have_attributes measure_ids: [measures[0].measure_sid] }
      end

      context 'for erga omnes assessment' do
        subject { presented_assessments[category_assessments[2].id].first }

        it { is_expected.to have_attributes measure_ids: [measures[2].measure_sid] }
      end
    end

    context 'when origin is does not match measure countries' do
      let(:geographical_area_id) { 'FR' }

      it { is_expected.to have_attributes length: 1 }
      it { is_expected.not_to include category_assessments[0].id }
      it { is_expected.not_to include category_assessments[1].id }
      it { is_expected.to include category_assessments[2].id }

      context 'for erga omnes assessment' do
        subject { presented_assessments[category_assessments[2].id].first }

        it { is_expected.to have_attributes measure_ids: [measures[2].measure_sid] }
      end
    end

    context 'with multiple measures for category assessments' do
      before do
        australia = create(:geographical_area, geographical_area_id: 'AU')

        measures << create(:measure,
                           generating_regulation: measures[0].generating_regulation,
                           measure_type_id: measures[0].measure_type_id,
                           for_geo_area: australia,
                           goods_nomenclature:)
      end

      it { is_expected.to have_attributes length: 3 }

      context 'for first assessment' do
        subject(:first) { presented_assessments[category_assessments[0].id] }

        it { is_expected.to have_attributes length: 2 }

        describe 'presented measure groups' do
          subject { first.map(&:measure_ids) }

          it { is_expected.to contain_exactly([measures[0].measure_sid], [measures[3].measure_sid]) }
        end
      end
    end
  end
end
