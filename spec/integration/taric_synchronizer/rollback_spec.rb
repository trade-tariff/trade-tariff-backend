RSpec.describe TaricSynchronizer, '.rollback' do
  subject(:rollback) { described_class.rollback(start_rollback_day.iso8601) }

  let(:start_rollback_day) { Time.zone.today - 3.days }

  let(:first_rolled_back_update) { create(:taric_update, :with_corresponding_data, example_date: start_rollback_day + 2.days) }
  let(:second_rolled_back_update) { create(:taric_update, :with_corresponding_data, example_date: start_rollback_day + 1.day) }
  let(:non_rolled_back_update) { create(:taric_update, :with_corresponding_data, example_date: start_rollback_day) }

  before do
    first_rolled_back_update
    second_rolled_back_update
    non_rolled_back_update
    allow(TradeTariffBackend).to receive(:service).and_return('xi')
  end

  it { is_expected.to have_rolled_back(first_rolled_back_update) }
  it { is_expected.to have_rolled_back(second_rolled_back_update) }
  it { is_expected.not_to have_rolled_back(non_rolled_back_update) }
end
