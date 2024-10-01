RSpec.describe Api::V2::GreenLanes::RegulationPresenter do
  subject { described_class.new(regulation) }

  let(:regulation) { create :base_regulation }

  it { is_expected.to have_attributes base_regulation_id: regulation.base_regulation_id }
  it { is_expected.to have_attributes published_date: regulation.published_date }
  it { is_expected.to have_attributes regulation_code: %r{[A-Z0-9]{5}/[A-Z0-9]{2}} }
  it { is_expected.to have_attributes regulation_url: %r{https://eur-lex.} }
  it { is_expected.to have_attributes description: be_present }
end
