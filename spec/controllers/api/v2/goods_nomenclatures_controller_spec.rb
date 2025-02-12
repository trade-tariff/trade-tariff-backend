RSpec.describe Api::V2::GoodsNomenclaturesController do
  routes { V2Api.routes }

  subject { response }

  before { commodity }

  render_views

  let(:commodity) { create :commodity, :with_indent, :with_chapter_and_heading }
  let(:section) { commodity.chapter.section }
  let(:response_rows) { response.body.lines.map { |row| row.strip.split(',') } }
  let(:response_json) { JSON.parse(response.body)['data'] }

  context 'when GNs for a section are requested' do
    context 'with a correct short code' do
      it 'returns rendered record of GNs in the section' do
        get :show_by_section, params: { position: section.position }, format: :json

        expect(response_json.map { |gn| gn['id'] }).to eq \
          [commodity.chapter, commodity.heading, commodity]
            .map(&:goods_nomenclature_sid)
            .map(&:to_s)
      end
    end

    context 'with an incorrect short code' do
      before { get :show_by_section, params: { position: '99' }, format: :json }

      it { is_expected.to have_http_status :not_found }
    end
  end

  context 'when GNs for a section are requested as CSV' do
    it 'returns rendered record of GNs in the section as CSV' do
      get :show_by_section, params: { position: section.position }, format: :csv

      expect(response_rows.map(&:first)).to eq \
        %w[SID] + [commodity.chapter, commodity.heading, commodity]
                    .map(&:goods_nomenclature_sid)
                    .map(&:to_s)
    end
  end

  context 'when GNs for a chapter are requested' do
    it 'returns rendered record of GNs in the chapter' do
      get :show_by_chapter, params: { chapter_id: commodity.chapter.short_code },
                            format: :json

      expect(response_json.map { |gn| gn['id'] }).to eq \
        [commodity.chapter, commodity.heading, commodity]
          .map(&:goods_nomenclature_sid)
          .map(&:to_s)
    end

    context 'with an incorrect short code' do
      before { get :show_by_chapter, params: { chapter_id: '99' }, format: :json }

      it { is_expected.to have_http_status :not_found }
    end
  end

  context 'when GNs for a chapter are requested as CSV' do
    it 'returns rendered record of GNs in the chapter as CSV' do
      get :show_by_chapter, params: { chapter_id: commodity.chapter.short_code },
                            format: :csv

      expect(response_rows.map(&:first)).to eq \
        %w[SID] + [commodity.chapter, commodity.heading, commodity]
                    .map(&:goods_nomenclature_sid)
                    .map(&:to_s)
    end
  end

  context 'when GNs for a heading are requested' do
    context 'with a correct short code' do
      it 'returns rendered record of GNs in the heading' do
        get :show_by_heading, params: { heading_id: commodity.heading.short_code },
                              format: :json

        expect(response_json.map { |gn| gn['id'] }).to eq \
          [commodity.heading, commodity].map(&:goods_nomenclature_sid).map(&:to_s)
      end
    end

    context 'with an incorrect short code' do
      before { get :show_by_heading, params: { heading_id: '9999' }, format: :json }

      it { is_expected.to have_http_status :not_found }
    end
  end

  context 'when GNs for a id is requested' do
    it 'returns rendered record of the GN' do
      get :show, params: { id: commodity.goods_nomenclature_item_id },
                 format: :json

      expect(response_json['id']).to eq commodity.goods_nomenclature_sid.to_s
    end

    context 'with an incorrect short code' do
      before { get :show, params: { id: '9922' }, format: :json }

      it { is_expected.to have_http_status :not_found }
    end
  end

  context 'when GNs for a heading are requested as CSV' do
    it 'returns rendered record of GNs in the heading as CSV' do
      get :show_by_heading, params: { heading_id: commodity.heading.short_code },
                            format: :csv

      expect(response_rows.map(&:first)).to eq \
        %w[SID] + [commodity.heading, commodity].map(&:goods_nomenclature_sid)
                                                .map(&:to_s)
    end
  end
end
