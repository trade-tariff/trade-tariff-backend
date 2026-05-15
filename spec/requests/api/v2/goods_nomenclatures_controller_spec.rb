RSpec.describe Api::V2::GoodsNomenclaturesController do
  subject(:api_response) do
    response
  end

  before { commodity }

  let(:commodity) { create :commodity, :with_indent, :with_chapter_and_heading }
  let(:section) { commodity.chapter.section }
  let(:response_rows) { response.body.lines.map { |row| row.strip.split(',') } }
  let(:response_json) { JSON.parse(response.body)['data'] }

  context 'when GNs for a section are requested' do
    context 'with a correct short code' do
      it 'returns api_response record of GNs in the section' do
        get "/uk/api/goods_nomenclatures/section/#{section.position}.json", headers: request_headers(format: :json)

        expect(response_json.map { |gn| gn['id'] }).to eq \
          [commodity.chapter, commodity.heading, commodity]
            .map(&:goods_nomenclature_sid)
            .map(&:to_s)
      end
    end

    context 'with an incorrect short code' do
      before { get '/uk/api/goods_nomenclatures/section/99.json', headers: request_headers(format: :json) }

      it { is_expected.to have_http_status :not_found }
    end
  end

  context 'when GNs for a section are requested as CSV' do
    it 'returns api_response record of GNs in the section as CSV' do
      get "/uk/api/goods_nomenclatures/section/#{section.position}.csv", headers: request_headers(format: :csv)

      expect(response_rows.map(&:first)).to eq \
        %w[SID] + [commodity.chapter, commodity.heading, commodity]
                    .map(&:goods_nomenclature_sid)
                    .map(&:to_s)
    end
  end

  context 'when GNs for a chapter are requested' do
    it 'returns api_response record of GNs in the chapter' do
      get "/uk/api/goods_nomenclatures/chapter/#{commodity.chapter.short_code}.json", headers: request_headers(format: :json)

      expect(response_json.map { |gn| gn['id'] }).to eq \
        [commodity.chapter, commodity.heading, commodity]
          .map(&:goods_nomenclature_sid)
          .map(&:to_s)
    end

    context 'with an incorrect short code' do
      before { get '/uk/api/goods_nomenclatures/chapter/99.json', headers: request_headers(format: :json) }

      it { is_expected.to have_http_status :not_found }
    end
  end

  context 'when GNs for a chapter are requested as CSV' do
    it 'returns api_response record of GNs in the chapter as CSV' do
      get "/uk/api/goods_nomenclatures/chapter/#{commodity.chapter.short_code}.csv", headers: request_headers(format: :csv)

      expect(response_rows.map(&:first)).to eq \
        %w[SID] + [commodity.chapter, commodity.heading, commodity]
                    .map(&:goods_nomenclature_sid)
                    .map(&:to_s)
    end
  end

  context 'when GNs for a heading are requested' do
    context 'with a correct short code' do
      it 'returns api_response record of GNs in the heading' do
        get "/uk/api/goods_nomenclatures/heading/#{commodity.heading.short_code}.json", headers: request_headers(format: :json)

        expect(response_json.map { |gn| gn['id'] }).to eq \
          [commodity.heading, commodity].map(&:goods_nomenclature_sid).map(&:to_s)
      end
    end

    context 'with an incorrect short code' do
      before { get '/uk/api/goods_nomenclatures/heading/9999.json', headers: request_headers(format: :json) }

      it { is_expected.to have_http_status :not_found }
    end
  end

  context 'when GNs for a id is requested' do
    it 'returns api_response record of the GN' do
      get "/uk/api/goods_nomenclatures/#{commodity.goods_nomenclature_item_id}.json", headers: request_headers(format: :json)

      expect(response_json['id']).to eq commodity.goods_nomenclature_sid.to_s
    end

    context 'with an incorrect short code' do
      before { get '/uk/api/goods_nomenclatures/9922.json', headers: request_headers(format: :json) }

      it { is_expected.to have_http_status :not_found }
    end
  end

  context 'when GNs for a heading are requested as CSV' do
    it 'returns api_response record of GNs in the heading as CSV' do
      get "/uk/api/goods_nomenclatures/heading/#{commodity.heading.short_code}.csv", headers: request_headers(format: :csv)

      expect(response_rows.map(&:first)).to eq \
        %w[SID] + [commodity.heading, commodity].map(&:goods_nomenclature_sid)
                                                .map(&:to_s)
    end
  end
end
