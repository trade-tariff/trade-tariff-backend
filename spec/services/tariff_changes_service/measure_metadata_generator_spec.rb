# frozen_string_literal: true

RSpec.describe TariffChangesService::MeasureMetadataGenerator do
  describe '.call' do
    let(:measure) { create(:measure) }

    context 'when measure exists' do
      it 'returns JSON with measure metadata' do
        metadata = described_class.call(measure.measure_sid)

        expect(metadata['measure']).to include(
          'measure_type_id' => measure.measure_type_id,
          'trade_movement_code' => measure.measure_type.trade_movement_code,
          'geographical_area_id' => measure.geographical_area_id,
        )
      end

      it 'includes excluded_geographical_area_ids key' do
        metadata = described_class.call(measure.measure_sid)

        expect(metadata['measure']).to have_key('excluded_geographical_area_ids')
      end

      context 'when measure has no excluded geographical areas' do
        it 'returns empty array for excluded_geographical_area_ids' do
          metadata = described_class.call(measure.measure_sid)

          expect(metadata['measure']['excluded_geographical_area_ids']).to eq([])
        end
      end

      context 'when measure has excluded geographical areas' do
        let(:excluded_area1) { create(:geographical_area) }
        let(:excluded_area2) { create(:geographical_area) }
        let(:excluded_area3) { create(:geographical_area) }

        before do
          create(:measure_excluded_geographical_area,
                 measure_sid: measure.measure_sid,
                 excluded_geographical_area: excluded_area2.geographical_area_id,
                 geographical_area_sid: excluded_area2.geographical_area_sid)
          create(:measure_excluded_geographical_area,
                 measure_sid: measure.measure_sid,
                 excluded_geographical_area: excluded_area1.geographical_area_id,
                 geographical_area_sid: excluded_area1.geographical_area_sid)
          create(:measure_excluded_geographical_area,
                 measure_sid: measure.measure_sid,
                 excluded_geographical_area: excluded_area3.geographical_area_id,
                 geographical_area_sid: excluded_area3.geographical_area_sid)
        end

        it 'includes all excluded geographical area ids' do
          metadata = described_class.call(measure.measure_sid)

          expect(metadata['measure']['excluded_geographical_area_ids']).to include(
            excluded_area1.geographical_area_id,
            excluded_area2.geographical_area_id,
            excluded_area3.geographical_area_id,
          )
        end

        it 'sorts excluded geographical area ids' do
          metadata = described_class.call(measure.measure_sid)
          excluded_ids = metadata['measure']['excluded_geographical_area_ids']

          expect(excluded_ids).to eq(excluded_ids.sort)
        end
      end

      context 'when measure has an additional code' do
        let(:additional_code) { create(:additional_code, :with_description) }

        before do
          measure.update(
            additional_code_sid: additional_code.additional_code_sid,
            additional_code_type_id: additional_code.additional_code_type_id,
            additional_code_id: additional_code.additional_code,
          )
        end

        it 'includes additional_code in metadata' do
          metadata = described_class.call(measure.measure_sid)

          expect(metadata['measure']).to have_key('additional_code')
          expect(metadata['measure']['additional_code']).to be_present
        end

        it 'formats additional code with code and description' do
          metadata = described_class.call(measure.measure_sid)

          # Code attribute includes the additional_code_type_id prefix
          expected = "#{additional_code.code}: #{additional_code.description}"
          expect(metadata['measure']['additional_code']).to eq(expected)
        end
      end

      context 'when measure has no additional code' do
        it 'returns empty string for additional_code' do
          metadata = described_class.call(measure.measure_sid)

          expect(metadata['measure']['additional_code']).to eq('')
        end
      end
    end

    context 'when measure does not exist' do
      it 'returns empty hash' do
        result = described_class.call(99_999)

        expect(result).to eq({})
      end
    end
  end
end
