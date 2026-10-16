RSpec.describe SearchReferences::ChangeEntry do
  describe '.from_version' do
    subject(:entry) do
      version = Version.by_item_type('SearchReference').by_event(event).order(Sequel.desc(:id)).first
      Version.preload_predecessors([version])
      described_class.from_version(version)
    end

    let(:commodity) { create(:commodity, goods_nomenclature_item_id: '0101210000') }
    let(:search_reference) do
      TradeTariffRequest.set(whodunnit: 'admin-uid') do
        create(:search_reference, referenced: commodity, title: 'live horses')
      end
    end

    context 'when the search reference was created' do
      let(:event) { 'create' }

      before { search_reference }

      it 'builds an added entry' do
        expect(entry).to have_attributes(
          section: :added,
          section_label: 'Added',
          search_reference_id: search_reference.id.to_s,
          goods_nomenclature_item_id: '0101210000',
          title: 'live horses',
          usage: 'search',
          changed_by: 'admin-uid',
          previous_title: nil,
          previous_usage: nil,
          successor_ids: [],
        )
      end

      it 'includes the frontend link' do
        expect(entry.goods_nomenclature_url).to eq("#{TradeTariffBackend.frontend_host}/commodities/0101210000")
      end
    end

    context 'when the search reference was updated' do
      let(:event) { 'update' }

      before do
        search_reference
        TradeTariffRequest.set(whodunnit: 'other-uid') do
          search_reference.update(title: 'horses, live', usage: SearchReference::FPO_USAGE)
        end
      end

      it 'builds an updated entry with the previous values' do
        expect(entry).to have_attributes(
          section: :updated,
          title: 'horses, live',
          usage: 'fpo',
          previous_title: 'live horses',
          previous_usage: 'search',
          changed_by: 'other-uid',
        )
      end

      it 'summarises the change in the alert line format' do
        expect(entry.summary).to eq(
          "0101210000 — horses, live [FPO only] (#{TradeTariffBackend.frontend_host}/commodities/0101210000) " \
          '(previously: title "live horses", usage search)',
        )
      end
    end

    context 'when the version stores the admin user name' do
      let(:event) { 'create' }
      let(:search_reference) do
        TradeTariffRequest.set(whodunnit: 'admin-uid', whodunnit_name: 'Jane Smith') do
          create(:search_reference, referenced: commodity, title: 'live horses')
        end
      end

      before { search_reference }

      it { is_expected.to have_attributes(changed_by: 'admin-uid', changed_by_name: 'Jane Smith') }
    end

    context 'when the version has no admin user name' do
      let(:event) { 'create' }

      before { search_reference }

      it { is_expected.to have_attributes(changed_by_name: nil) }
    end

    context 'when an admin user deleted the search reference' do
      let(:event) { 'destroy' }

      before do
        search_reference
        TradeTariffRequest.set(whodunnit: 'admin-uid') { search_reference.destroy }
      end

      it { is_expected.to have_attributes(section: :deleted, section_label: 'Manually deleted', changed_by: 'admin-uid') }
    end

    context 'when ClearInvalidSearchReferences stored the removal reason' do
      let(:event) { 'destroy' }

      before do
        search_reference
        search_reference.version_metadata = { removal_reason: 'expired', successor_ids: [] }
        TradeTariffRequest.set(whodunnit: ClearInvalidSearchReferences::WHODUNNIT) { search_reference.destroy }
      end

      it { is_expected.to have_attributes(section: :expired, section_label: 'Expired', successor_ids: [], changed_by: 'ClearInvalidSearchReferences') }

      it 'does not derive the reason again from the current tariff data' do
        allow(SearchReferences::InvalidationReasonService).to receive(:call)
        entry
        expect(SearchReferences::InvalidationReasonService).not_to have_received(:call)
      end
    end

    context 'when ClearInvalidSearchReferences stored a superseded reason' do
      let(:event) { 'destroy' }

      before do
        search_reference
        search_reference.version_metadata = { removal_reason: 'superseded', successor_ids: %w[0101999000 0101888000] }
        TradeTariffRequest.set(whodunnit: ClearInvalidSearchReferences::WHODUNNIT) { search_reference.destroy }
      end

      it { is_expected.to have_attributes(section: :superseded, successor_ids: %w[0101999000 0101888000]) }
      it { expect(entry.summary).to include('(successors: 0101999000, 0101888000)') }
    end

    context 'when the stored reason is not a removal reason' do
      let(:event) { 'destroy' }

      before do
        search_reference
        search_reference.version_metadata = { removal_reason: 'current', successor_ids: %w[0101999000] }
        TradeTariffRequest.set(whodunnit: ClearInvalidSearchReferences::WHODUNNIT) { search_reference.destroy }
      end

      it { is_expected.to have_attributes(section: :unknown, successor_ids: []) }
    end

    context 'when an automatic removal has no stored reason' do
      let(:event) { 'destroy' }
      let(:commodity) { create(:commodity, goods_nomenclature_item_id: '0101210000', validity_end_date: Time.zone.yesterday) }

      before do
        TimeMachine.now { search_reference }
        TradeTariffRequest.set(whodunnit: ClearInvalidSearchReferences::WHODUNNIT) { search_reference.destroy }
      end

      it { is_expected.to have_attributes(section: :unknown, successor_ids: []) }
    end

    context 'when the backfill wrote the removal' do
      let(:event) { 'destroy' }

      before do
        search_reference
        TradeTariffRequest.set(whodunnit: 'ClearInvalidSearchReferences (backfill)') { search_reference.destroy }
      end

      it { is_expected.to have_attributes(section: :unknown, source: 'Automatic clean-up (backfill)') }
    end

    context 'when the version has no whodunnit' do
      let(:event) { 'create' }

      before { TradeTariffRequest.set(whodunnit: nil) { create(:search_reference, referenced: commodity) } }

      it { is_expected.to have_attributes(changed_by: 'Unknown') }
    end
  end

  describe '#source, #admin_user? and #changed_by_label' do
    subject(:entry) do
      described_class.new(
        version_id: 1,
        search_reference_id: '1',
        section: :added,
        changed_at: Time.utc(2026, 10, 3),
        changed_by:,
        changed_by_name:,
        goods_nomenclature_item_id: '0101210000',
        productline_suffix: '80',
        title: 'live horses',
        usage: SearchReference::SEARCH_USAGE,
        goods_nomenclature_url: nil,
        successor_ids: [],
        previous_goods_nomenclature_item_id: nil,
        previous_title: nil,
        previous_usage: nil,
      )
    end

    let(:changed_by) { '11111111-1111-4111-8111-111111111111' }
    let(:changed_by_name) { nil }

    it { is_expected.to have_attributes(source: 'Admin user', admin_user?: true, changed_by_label: 'Admin user') }

    context 'when the admin user has a name' do
      let(:changed_by_name) { 'Jane Smith' }

      it { is_expected.to have_attributes(changed_by_label: 'Jane Smith') }
    end

    context 'when a job made the change' do
      let(:changed_by) { 'ClearInvalidSearchReferences' }
      let(:changed_by_name) { 'ignored' }

      it { is_expected.to have_attributes(admin_user?: false, changed_by_label: 'Automatic clean-up') }
    end
  end
end
