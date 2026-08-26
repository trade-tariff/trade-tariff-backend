RSpec.describe ClearInvalidSearchReferences, type: :worker do
  subject(:do_perform) { silence { described_class.new.perform } }

  let(:notify_double) { instance_double(GovukNotifier, send_email: true) }

  before do
    allow(GovukNotifier).to receive(:new).and_return(notify_double)
  end

  context 'when a search reference is expired with no successor' do
    before do
      TimeMachine.now do
        create(:search_reference, :with_non_current_commodity, title: 'foo')
        create(:search_reference, :with_current_commodity, title: 'bar')
      end
    end

    it 'deletes the expired search reference only' do
      expect { do_perform }.to change(SearchReference, :count).by(-1)
    end

    it 'sends an invalidation alert email listing it under expired' do
      do_perform

      expect(notify_double).to have_received(:send_email).with(
        TradeTariffBackend.support_email,
        ClearInvalidSearchReferences::TEMPLATE_ID,
        hash_including(
          removed_count: 1,
          flagged_count: 0,
          has_expired: true,
          has_missing: false,
          has_superseded: false,
          has_unknown: false,
          expired_list: a_string_including('foo'),
        ),
      )
    end
  end

  context 'when all search references are current' do
    before do
      TimeMachine.now do
        create(:search_reference, :with_current_commodity, title: 'foo')
        create(:search_reference, :with_current_commodity, title: 'bar')
      end
    end

    it 'does not delete anything' do
      expect { do_perform }.not_to change(SearchReference, :count)
    end

    it 'does not send an invalidation alert email' do
      do_perform
      expect(notify_double).not_to have_received(:send_email)
    end
  end

  context 'when a search reference points at a future-dated goods nomenclature' do
    let(:commodity) { create(:commodity, validity_start_date: Time.zone.tomorrow, validity_end_date: nil) }

    before do
      TimeMachine.now { create(:search_reference, referenced: commodity, title: 'future item') }
    end

    it 'retains the search reference instead of deleting it' do
      expect { do_perform }.not_to change(SearchReference, :count)
    end

    it 'does not send an invalidation alert email' do
      do_perform
      expect(notify_double).not_to have_received(:send_email)
    end
  end

  context 'when a search reference is superseded' do
    let(:commodity) { create(:commodity, validity_end_date: Time.zone.yesterday) }

    before do
      TimeMachine.now do
        create(:search_reference, referenced: commodity, title: 'superseded item')
        create(
          :goods_nomenclature_successor,
          absorbed_goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
          absorbed_productline_suffix: commodity.producline_suffix,
          goods_nomenclature_item_id: '0101999000',
        )
      end
    end

    it 'flags it for review instead of deleting it' do
      expect { do_perform }.not_to change(SearchReference, :count)
    end

    it 'sends an invalidation alert email listing it under superseded' do
      do_perform

      expect(notify_double).to have_received(:send_email).with(
        TradeTariffBackend.support_email,
        ClearInvalidSearchReferences::TEMPLATE_ID,
        hash_including(
          removed_count: 0,
          flagged_count: 1,
          has_superseded: true,
          superseded_list: a_string_including('superseded item', '0101999000'),
        ),
      )
    end
  end

  context 'when no support email is configured' do
    before do
      allow(TradeTariffBackend).to receive(:support_email).and_return(nil)
      TimeMachine.now { create(:search_reference, :with_non_current_commodity, title: 'foo') }
    end

    it 'still deletes the expired search reference' do
      expect { do_perform }.to change(SearchReference, :count).by(-1)
    end

    it 'does not attempt to send an email' do
      do_perform
      expect(notify_double).not_to have_received(:send_email)
    end
  end

  context 'when processing one search reference raises an error' do
    let(:bad_search_reference) { create(:search_reference, :with_non_current_commodity, title: 'bad') }
    let(:good_search_reference) { create(:search_reference, :with_non_current_commodity, title: 'good') }

    before do
      TimeMachine.now do
        bad_search_reference
        good_search_reference
      end

      allow(SearchReferences::InvalidationReasonService).to receive(:call).and_call_original
      allow(SearchReferences::InvalidationReasonService).to receive(:call)
        .with(an_object_having_attributes(title: 'bad'))
        .and_raise(StandardError, 'boom')
    end

    it 'does not raise and still processes the remaining search reference' do
      expect { do_perform }.not_to raise_error

      expect(SearchReference[bad_search_reference.id]).not_to be_nil
      expect(SearchReference[good_search_reference.id]).to be_nil
    end

    it 'still sends an invalidation alert email for the successfully processed reference' do
      do_perform

      expect(notify_double).to have_received(:send_email).with(
        TradeTariffBackend.support_email,
        ClearInvalidSearchReferences::TEMPLATE_ID,
        hash_including(removed_count: 1, expired_list: a_string_including('good')),
      )
    end
  end

  context 'when sending the alert email fails' do
    before do
      allow(notify_double).to receive(:send_email).and_raise(StandardError, 'boom')
      TimeMachine.now { create(:search_reference, :with_non_current_commodity, title: 'foo') }
    end

    it 'still keeps the deletion that already happened' do
      expect { do_perform }.to change(SearchReference, :count).by(-1)
    end

    it 'does not raise' do
      expect { do_perform }.not_to raise_error
    end
  end
end
