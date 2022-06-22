RSpec.describe TariffSynchronizer, '.rollback_cds' do
  subject(:rollback_cds) { described_class.rollback_cds('2021-01-01') }

  let(:first_rolled_back_update) { create(:cds_update, :with_corresponding_data, example_date: Date.parse('2021-01-03')) }
  let(:second_rolled_back_update) { create(:cds_update, :with_corresponding_data, example_date: Date.parse('2021-01-02')) }
  let(:non_rolled_back_update) { create(:cds_update, :with_corresponding_data, example_date: Date.parse('2021-01-01')) }

  before do
    first_rolled_back_update
    second_rolled_back_update
    non_rolled_back_update
  end

  it { is_expected.to have_rolled_back(first_rolled_back_update) }
  it { is_expected.to have_rolled_back(second_rolled_back_update) }
  it { is_expected.not_to have_rolled_back(non_rolled_back_update) }
end
