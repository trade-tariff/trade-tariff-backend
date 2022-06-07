RSpec.describe ClearInvalidSearchReferences, type: :worker do
  subject(:do_perform) { silence { described_class.new.perform } }

  before do
    create(:search_reference, :with_current_commodity)
    create(:search_reference, :with_non_current_commodity)
  end

  it { expect { do_perform }.to change(SearchReference, :count).by(-1) }
end
