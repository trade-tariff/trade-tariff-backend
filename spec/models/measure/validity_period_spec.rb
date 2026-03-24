RSpec.describe Measure::ValidityPeriod do
  subject(:validity_period) { described_class.new(measure) }

  # Helpers that build a minimal measure double wired to a generating regulation.
  def measure_double(national:, measure_end_date:, regulation_end_date:, justification_present: false)
    regulation = instance_double(
      BaseRegulation,
      effective_end_date: regulation_end_date,
      present?: regulation_end_date.present?,
    )
    allow(regulation).to receive(:present?).and_return(true)

    instance_double(
      Measure,
      national?: national,
      '[]': measure_end_date,
      justification_regulation_present?: justification_present,
      generating_regulation: regulation,
    )
  end

  describe '#end_date' do
    context 'when the measure is national' do
      context 'with no measure end date' do
        let(:measure) { measure_double(national: true, measure_end_date: nil, regulation_end_date: Time.zone.tomorrow) }

        it 'returns nil, ignoring the regulation end date' do
          expect(validity_period.end_date).to be_nil
        end
      end

      context 'with a measure end date' do
        let(:today) { Time.zone.today }
        let(:measure) { measure_double(national: true, measure_end_date: today, regulation_end_date: Time.zone.tomorrow) }

        it 'returns the raw measure end date, ignoring the regulation end date' do
          expect(validity_period.end_date).to eq today
        end
      end
    end

    context 'when the measure is not national' do
      context 'when both the measure and regulation have end dates' do
        context 'when the measure end date is earlier' do
          let(:today) { Time.zone.today }
          let(:measure) { measure_double(national: false, measure_end_date: today, regulation_end_date: Time.zone.tomorrow) }

          it 'returns the measure end date (the minimum)' do
            expect(validity_period.end_date).to eq today
          end
        end

        context 'when the regulation end date is earlier' do
          let(:tomorrow) { Time.zone.tomorrow }
          let(:measure) { measure_double(national: false, measure_end_date: 1.week.from_now.to_date, regulation_end_date: tomorrow) }

          it 'returns the regulation end date (the minimum)' do
            expect(validity_period.end_date).to eq tomorrow
          end
        end
      end

      context 'when only the measure has an end date' do
        context 'when there is no justification regulation' do
          let(:measure) { measure_double(national: false, measure_end_date: Time.zone.today, regulation_end_date: nil) }

          it 'returns nil because the regulation caps the date' do
            expect(validity_period.end_date).to be_nil
          end
        end

        context 'when there is a justification regulation present' do
          let(:today) { Time.zone.today }
          let(:measure) { measure_double(national: false, measure_end_date: today, regulation_end_date: nil, justification_present: true) }

          it 'returns the measure end date' do
            expect(validity_period.end_date).to eq today
          end
        end
      end

      context 'when only the regulation has an end date' do
        let(:tomorrow) { Time.zone.tomorrow }
        let(:measure) { measure_double(national: false, measure_end_date: nil, regulation_end_date: tomorrow) }

        it 'returns the regulation end date' do
          expect(validity_period.end_date).to eq tomorrow
        end
      end

      context 'when neither the measure nor the regulation has an end date' do
        let(:measure) { measure_double(national: false, measure_end_date: nil, regulation_end_date: nil) }

        it 'returns nil' do
          expect(validity_period.end_date).to be_nil
        end
      end
    end
  end
end
