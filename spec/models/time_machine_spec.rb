RSpec.describe TimeMachine do
  let!(:first_commodity) do
    create :commodity, validity_start_date: Time.zone.now.ago(1.day),
                       validity_end_date: Time.zone.now.in(1.day)
  end
  let!(:second_commodity) do
    create :commodity, validity_start_date: Time.zone.now.ago(20.days),
                       validity_end_date: Time.zone.now.ago(10.days)
  end

  describe '.at' do
    it 'sets date to current date if argument is blank', :aggregate_failures do
      described_class.at(nil) do
        expect(Commodity.actual.all).to     include first_commodity
        expect(Commodity.actual.all).not_to include second_commodity
      end
    end

    it 'sets date to current date if argument is erroneous', :aggregate_failures do
      described_class.at('#&$*(#)') do
        expect(Commodity.actual.all).to     include first_commodity
        expect(Commodity.actual.all).not_to include second_commodity
      end
    end

    it 'parses and sets valid date from argument', :aggregate_failures do
      described_class.at(Time.zone.now.ago(15.days).to_s) do
        expect(Commodity.actual.all).not_to include first_commodity
        expect(Commodity.actual.all).to     include second_commodity
      end
    end

    it 'uses the configured time zone for a date string with an explicit offset', :aggregate_failures do
      described_class.at('2024-06-01T12:34:56+01:00') do
        point_in_time = described_class.point_in_time

        expect(point_in_time).to be_a(ActiveSupport::TimeWithZone)
        expect(point_in_time).to eq(Time.iso8601('2024-06-01T12:34:56+01:00'))
        expect(point_in_time.time_zone).to eq(Time.zone)
      end
    end

    it 'parses a Date at midnight' do
      described_class.at(Date.new(2024, 6, 1)) do
        expect(described_class.point_in_time).to eq(Time.zone.local(2024, 6, 1))
      end
    end

    it 'restores the outer point in time after nested travel' do
      described_class.at('2024-06-01') do
        outer_point_in_time = described_class.point_in_time

        described_class.at('2025-07-02') do
          expect(described_class.point_in_time).to eq(Time.zone.local(2025, 7, 2))
        end

        expect(described_class.point_in_time).to eq(outer_point_in_time)
      end
    end
  end

  describe '.now' do
    it 'sets date to current date', :aggregate_failures do
      described_class.now do
        expect(Commodity.actual.all).to     include first_commodity
        expect(Commodity.actual.all).not_to include second_commodity
      end
    end
  end

  describe '.no_time_machine' do
    it { described_class.no_time_machine { expect(Commodity.point_in_time).to be_nil } }
  end

  describe '.date_is_set?' do
    subject { described_class.date_is_set? }

    context 'when date is set' do
      around { |example| described_class.now { example.run } }

      it { is_expected.to be true }
    end

    context 'when date is not set' do
      around { |example| described_class.no_time_machine { example.run } }

      it { is_expected.to be false }
    end
  end

  describe '.point_in_time' do
    subject { described_class.point_in_time }

    context 'when date is set' do
      around { |example| described_class.now { example.run } }

      it { is_expected.not_to be_nil }
    end

    context 'when date is not set' do
      around { |example| described_class.no_time_machine { example.run } }

      it { is_expected.to be_nil }
    end
  end
end
