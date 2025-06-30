RSpec.describe Sequel::Plugins::TimeMachine do
  shared_context 'with TimeMachine' do
    around do |example|
      TimeMachine.at(10.minutes.ago) { example.run }
    end
  end

  shared_context 'without TimeMachine' do
    around do |example|
      TimeMachine.no_time_machine { example.run }
    end
  end

  describe '#point_in_time' do
    subject { Commodity.point_in_time }

    context 'when inside time machine' do
      include_context 'with TimeMachine'

      it { is_expected.to be_present }
    end

    context 'when outside time machine' do
      include_context 'without TimeMachine'

      it { is_expected.to be_nil }
    end
  end

  describe '#with_validity_dates' do
    subject { Commodity.dataset.with_validity_dates.sql }

    context 'when inside time machine' do
      include_context 'with TimeMachine'

      it { is_expected.to match '"validity_end_date" IS NULL' }
    end

    context 'when outside time machine' do
      include_context 'without TimeMachine'

      it { is_expected.not_to match 'validity_end_date' }
    end
  end

  describe '#validity_dates_filter' do
    subject do
      Commodity.dataset
               .where { Commodity.validity_dates_filter(:testtable) }
               .sql
    end

    context 'when inside time machine' do
      include_context 'with TimeMachine'

      it { is_expected.to match '"validity_end_date" IS NULL' }
    end

    context 'when outside time machine' do
      include_context 'without TimeMachine'

      it { is_expected.not_to match 'validity_end_date' }
      it { is_expected.to match 'AND true' }
    end
  end
end
