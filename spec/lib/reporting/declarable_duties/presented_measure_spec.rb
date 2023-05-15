RSpec.describe Reporting::DeclarableDuties::PresentedMeasure do
  subject(:presented_measure) { described_class.new(measure) }

  let(:measure) { create(:measure) }

  describe '#measure__sid' do
    it { expect(presented_measure.measure__sid).to eq measure.measure_sid }
  end

  describe '#measure__type__id' do
    it { expect(presented_measure.measure__type__id).to eq measure.measure_type_id }
  end

  describe '#measure__type__description' do
    it { expect(presented_measure.measure__type__description).to eq measure.measure_type.description }
  end

  describe '#measure__additional_code__code' do
    context 'when additional code is not present' do
      let(:measure) { create(:measure) }

      it { expect(presented_measure.measure__additional_code__code).to be_nil }
    end

    context 'when additional code is present' do
      let(:measure) { create(:measure, additional_code: create(:additional_code)) }

      it { expect(presented_measure.measure__additional_code__code).to eq measure.additional_code.code }
    end
  end

  describe '#measure__additional_code__description' do
    context 'when additional code is not present' do
      it { expect(presented_measure.measure__additional_code__description).to be_nil }
    end

    context 'when additional code is present' do
      let(:measure) { create(:measure, additional_code: create(:additional_code, :with_description)) }

      it { expect(presented_measure.measure__additional_code__description).to eq measure.additional_code.description }
    end
  end

  describe '#measure__duty_expression' do
    context 'when measure has no measure components' do
      it { expect(presented_measure.measure__duty_expression).to eq '' }
    end

    context 'when measure has measure components' do
      let(:measure) { create(:measure, :with_measure_components) }

      it { expect(presented_measure.measure__duty_expression).to be_present }
    end
  end

  describe '#measure__effective_start_date' do
    it { expect(presented_measure.measure__effective_start_date).to eq measure.validity_start_date.to_date.iso8601 }
  end

  describe '#measure__effective_end_date' do
    it { expect(presented_measure.measure__effective_end_date).to be_nil }
  end

  describe '#measure_reduction_indicator' do
    it { expect(presented_measure.measure_reduction_indicator).to eq measure.reduction_indicator }
  end

  describe '#measure__footnotes' do
    context 'when there are no footnotes' do
      it { expect(presented_measure.measure__footnotes).to be_nil }
    end

    context 'when there are footnotes' do
      let(:measure) { create(:measure, :with_footnote_association) }

      it { expect(presented_measure.measure__footnotes).to eq measure.footnotes.map(&:code).join('|') }
    end
  end

  describe '#measure__conditions' do
    context 'when there are no measure conditions' do
      it { expect(presented_measure.measure__conditions).to be_nil }
    end

    context 'when there are measure conditions' do
      let(:measure) { create(:measure, :with_measure_conditions) }

      it { expect(presented_measure.measure__conditions).to eq 'condition:B,action:01' }
    end
  end

  describe '#measure__geographical_area__sid' do
    it { expect(presented_measure.measure__geographical_area__sid).to eq measure.geographical_area_sid }
  end

  describe '#measure__geographical_area__id' do
    it { expect(presented_measure.measure__geographical_area__id).to eq measure.geographical_area_id }
  end

  describe '#measure__geographical_area__description' do
    it { expect(presented_measure.measure__geographical_area__description).to eq measure.geographical_area.description }
  end

  describe '#measure__excluded_geographical_areas__ids' do
    context 'when there are no excluded geographical areas' do
      it { expect(presented_measure.measure__excluded_geographical_areas__ids).to eq '' }
    end

    context 'when there are excluded geographical areas' do
      let(:measure) { create(:measure, :with_measure_excluded_geographical_area) }

      it { expect(presented_measure.measure__excluded_geographical_areas__ids).to eq measure.excluded_geographical_areas.map(&:geographical_area_id).join('|') }
    end
  end

  describe '#measure__excluded_geographical_areas__descriptions' do
    context 'when there are no excluded geographical areas' do
      it { expect(presented_measure.measure__excluded_geographical_areas__descriptions).to eq '' }
    end

    context 'when there are excluded geographical areas' do
      let(:measure) { create(:measure, :with_measure_excluded_geographical_area) }

      it { expect(presented_measure.measure__excluded_geographical_areas__descriptions).to be_present }
    end
  end

  describe '#measure__quota__order_number' do
    it { expect(presented_measure.measure__quota__order_number).to eq measure.ordernumber }
  end

  describe '#measure__quota__available' do
    context 'when measure has no quota definition' do
      it { expect(presented_measure.measure__quota__available).to eq '' }
    end

    context 'when measure has quota definition and the quota is a licensed quota' do
      let(:measure) { create(:measure, :with_quota_definition, ordernumber: '094001') }

      it { expect(presented_measure.measure__quota__available).to eq 'See RPA' }
    end

    context 'when measure has quota definition and the quota balance is positive' do
      let(:measure) { create(:measure, :with_quota_definition, initial_volume: 1000, ordernumber: '092002') }

      it { expect(presented_measure.measure__quota__available).to eq 'Open' }
    end

    context 'when measure has quota definition and the quota balance is not positive' do
      let(:measure) { create(:measure, :with_quota_definition, initial_volume: 0, ordernumber: '092002') }

      it { expect(presented_measure.measure__quota__available).to eq 'Exhausted' }
    end

    context 'when the measure has no quota definition but has a quota order number' do
      let(:measure) { create(:measure, ordernumber: '092002') }

      it { expect(presented_measure.measure__quota__available).to eq 'Invalid' }
    end
  end

  describe '#measure__regulation__id' do
    it { expect(presented_measure.measure__regulation__id).to eq measure.measure_generating_regulation_id }
  end

  describe '#measure__regulation__url' do
    before do
      legal_act_presenter = instance_double(Api::V2::Measures::MeasureLegalActPresenter, regulation_url: 'http://example.com')
      allow(Api::V2::Measures::MeasureLegalActPresenter).to receive(:new).and_return(legal_act_presenter)
    end

    it { expect(presented_measure.measure__regulation__url).to eq 'http://example.com' }
  end
end
