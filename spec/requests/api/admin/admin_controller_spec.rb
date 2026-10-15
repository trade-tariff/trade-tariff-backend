RSpec.describe Api::Admin::AdminController do
  describe 'X-Whodunnit-Name header' do
    subject(:version) do
      post "/uk/admin/headings/#{heading.goods_nomenclature_item_id.first(4)}/search_references.json",
           params: { data: { type: :search_reference, attributes: { title: 'lunch box' } } },
           headers: request_headers(headers),
           as: :json

      Version.by_item_type(SearchReference.name).most_recent_first.first
    end

    let(:heading) { create :heading }

    before { allow(ScoreLabelBatchWorker).to receive(:perform_async) }

    after { TradeTariffRequest.reset }

    context 'with an admin user ID and name' do
      let(:headers) { { 'X-Whodunnit' => 'user-123', 'X-Whodunnit-Name' => 'Jane%20Smith' } }

      it { is_expected.to have_attributes(whodunnit: 'user-123', whodunnit_name: 'Jane Smith') }
    end

    context 'with a URL-encoded name that has non-ASCII characters' do
      let(:headers) { { 'X-Whodunnit' => 'user-123', 'X-Whodunnit-Name' => 'Zo%C3%AB' } }

      it { is_expected.to have_attributes(whodunnit_name: 'Zoë') }
    end

    context 'with a name that is too long' do
      let(:headers) { { 'X-Whodunnit' => 'user-123', 'X-Whodunnit-Name' => 'a' * 300 } }

      it { expect(version.whodunnit_name.length).to eq(described_class::WHODUNNIT_NAME_MAX_LENGTH) }
    end

    context 'without a name header' do
      let(:headers) { { 'X-Whodunnit' => 'user-123' } }

      it { is_expected.to have_attributes(whodunnit: 'user-123', whodunnit_name: nil) }
    end

    context 'with a name but no user ID' do
      let(:headers) { { 'X-Whodunnit-Name' => 'Jane%20Smith' } }

      it { is_expected.to have_attributes(whodunnit: nil, whodunnit_name: nil) }
    end
  end
end
