RSpec.describe ClearInvalidSearchReferences, type: :worker do
  subject(:do_perform) { silence { described_class.new.perform } }

  context 'when the are search references to clear' do
    before do
      create(:search_reference, :with_non_current_commodity, title: 'foo')
      create(:search_reference, :with_current_commodity, title: 'bar')
    end

    it { expect { do_perform }.to change(SearchReference, :count).by(-1) }

    it 'sends a slack notification about expiring search references' do
      allow(SlackNotifierService).to receive(:call).and_call_original
      do_perform
      expect(SlackNotifierService).to have_received(:call).with(match(/foo/))
    end

    it 'does not send a slack notification about non-expiring search references' do
      allow(SlackNotifierService).to receive(:call).and_call_original
      do_perform
      expect(SlackNotifierService).not_to have_received(:call).with(match(/bar/))
    end
  end

  context 'when there are no search references to clear' do
    before do
      create(:search_reference, :with_current_commodity, title: 'foo')
      create(:search_reference, :with_current_commodity, title: 'bar')
    end

    it { expect { do_perform }.not_to change(SearchReference, :count) }

    it 'does not send a slack notification' do
      allow(SlackNotifierService).to receive(:call).and_call_original
      do_perform
      expect(SlackNotifierService).not_to have_received(:call)
    end
  end
end
