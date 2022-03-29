RSpec.describe MeasureAction do
  shared_examples_for 'a positive measure action' do |action_code|
    subject(:measure_action) { build(:measure_action, action_code: action_code) }

    it { is_expected.to be_positive_action }
  end

  shared_examples_for 'a negative measure action' do |action_code|
    subject(:measure_action) { build(:measure_action, action_code: action_code) }

    it { is_expected.to be_negative_action }
  end

  it_behaves_like 'a positive measure action', '01'
  it_behaves_like 'a positive measure action', '24'
  it_behaves_like 'a positive measure action', '25'
  it_behaves_like 'a positive measure action', '26'
  it_behaves_like 'a positive measure action', '27'
  it_behaves_like 'a positive measure action', '28'
  it_behaves_like 'a positive measure action', '29'
  it_behaves_like 'a positive measure action', '34'
  it_behaves_like 'a positive measure action', '36'

  it_behaves_like 'a negative measure action', '04'
  it_behaves_like 'a negative measure action', '05'
  it_behaves_like 'a negative measure action', '06'
  it_behaves_like 'a negative measure action', '07'
  it_behaves_like 'a negative measure action', '08'
  it_behaves_like 'a negative measure action', '09'
  it_behaves_like 'a negative measure action', '16'
end
