RSpec.describe ClearInvalidSearchReferences, type: :worker do
  subject(:do_perform) { silence { described_class.new.perform } }

  context 'when the are search references to clear' do
    before do
      TimeMachine.now do
        create(:search_reference, :with_non_current_commodity, title: 'foo')
        create(:search_reference, :with_current_commodity, title: 'bar')
      end
    end

    it { expect { do_perform }.to change(SearchReference, :count).by(-1) }

    it 'does not send a Slack notification' do
      expect(SlackNotifierService).not_to receive(:call)
      do_perform
    end
  end

  context 'when there are no search references to clear' do
    before do
      TimeMachine.now do
        create(:search_reference, :with_current_commodity, title: 'foo')
        create(:search_reference, :with_current_commodity, title: 'bar')
      end
    end

    it { expect { do_perform }.not_to change(SearchReference, :count) }

    it 'does not send a Slack notification' do
      expect(SlackNotifierService).not_to receive(:call)
      do_perform
    end
  end
end
