RSpec.describe Api::V1::ChaptersController do
  routes { V1Api.routes }

  let(:now) { Time.zone.today }
  let(:expires_at) { now.end_of_day }

  before do
    TradeTariffRequest.time_machine_now = Time.current
    allow(Rails.cache).to receive(:fetch).and_call_original
  end

  render_views

  describe 'GET #show' do
    before do
      create :section_note, section: chapter.section
    end

    let!(:chapter) { create :chapter, :with_description, :with_section, goods_nomenclature_item_id: '1100000000' }

    let(:pattern) do
      {
        goods_nomenclature_item_id: chapter.code,
        description: String,
        headings: Array,
        section: {
          section_note: String,
        }.ignore_extra_keys!,
        _response_info: Hash,
      }.ignore_extra_keys!
    end

    context 'when record is present' do
      it 'caches the serialized chapter' do
        get :show, params: { id: chapter.short_code }, format: :json

        expect(Rails.cache)
          .to have_received(:fetch)
          .with(
            "_v1_chapter-#{chapter.short_code}-#{now.iso8601}-view",
            expires_at:,
          )
      end

      it 'returns rendered record' do
        get :show, params: { id: chapter }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when record is not present' do
      it 'returns not found if record was not found' do
        id = chapter.goods_nomenclature_item_id.first(2).to_i + 1
        get :show, params: { id: }, format: :json

        expect(response.status).to eq 404
      end
    end

    context 'when record is hidden' do
      it 'returns not found' do
        create :hidden_goods_nomenclature, goods_nomenclature_item_id: chapter.goods_nomenclature_item_id
        get :show, params: { id: chapter.goods_nomenclature_item_id.first(2) }, format: :json

        expect(response.status).to eq 404
      end
    end
  end

  describe 'GET #index' do
    before do
      create :chapter, :with_section, :with_note
      create :chapter, :with_section, :with_note
    end

    let(:pattern) do
      [
        { goods_nomenclature_item_id: String, chapter_note_id: Integer },
        { goods_nomenclature_item_id: String, chapter_note_id: Integer },
      ]
    end

    it 'caches the serialized chapters' do
      get :index, format: :json

      expect(Rails.cache)
        .to have_received(:fetch)
        .with(
          "_v1_chapters-#{now.iso8601}-view",
          expires_at:,
        )
    end

    it 'returns rendered records' do
      get :index, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end

  describe 'GET #changes' do
    context 'when changes happened after chapter creation' do
      let(:chapter) { create :chapter, :with_section, :with_note, operation_date: Time.zone.today }

      let(:pattern) do
        [
          {
            oid: Integer,
            model_name: 'Measure',
            record: {
              measure_type: {
                description: String,
              }.ignore_extra_keys!,
            }.ignore_extra_keys!,
          }.ignore_extra_keys!,
          {
            oid: Integer,
            model_name: 'Chapter',
            operation: String,
            operation_date: String,
            record: {
              description: String,
              goods_nomenclature_item_id: String,
              validity_start_date: String,
              validity_end_date: nil,
            },
          },
        ].ignore_extra_values!
      end

      let(:heading) { create :heading, goods_nomenclature_item_id: "#{chapter.goods_nomenclature_item_id.first(2)}20000000" }

      before do
        create :measure,
               :with_measure_type,
               goods_nomenclature: heading,
               goods_nomenclature_sid: heading.goods_nomenclature_sid,
               goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
               operation_date: Time.zone.today
      end

      it 'caches the serialized chapter changes' do
        get :changes, params: { id: chapter.short_code }, format: :json

        expect(Rails.cache)
          .to have_received(:fetch)
          .with(
            "_v1_chapter-#{chapter.short_code}-#{now.iso8601}/changes-view",
            expires_at:,
          )
      end

      it 'returns chapter changes' do
        get :changes, params: { id: chapter.short_code }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when changes happened before requested date' do
      let(:chapter) do
        create :chapter, :with_section, :with_note,
               operation_date: Time.zone.today
      end
      let(:heading) { create :heading, goods_nomenclature_item_id: "#{chapter.goods_nomenclature_item_id.first(2)}20000000" }

      it 'does not include change records' do
        create :measure,
               :with_measure_type,
               goods_nomenclature: heading,
               goods_nomenclature_sid: heading.goods_nomenclature_sid,
               goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
               operation_date: Time.zone.today

        get :changes, params: { id: chapter, as_of: Time.zone.yesterday }, format: :json

        expect(response.body).to match_json_expression []
      end
    end

    context 'when changes include deleted record' do
      let(:chapter) do
        create :chapter, :with_section, :with_note,
               operation_date: Time.zone.today
      end

      let(:heading) { create :heading, goods_nomenclature_item_id: "#{chapter.goods_nomenclature_item_id.first(2)}20000000" }

      let(:pattern) do
        [
          {
            oid: Integer,
            model_name: 'Measure',
            operation: 'D',
            record: {
              goods_nomenclature_item_id: /\d{10}/,
              measure_type: {
                description: String,
              }.ignore_extra_keys!,
            }.ignore_extra_keys!,
          }.ignore_extra_keys!,
          {
            oid: Integer,
            model_name: 'Chapter',
            operation: String,
            operation_date: String,
            record: {
              description: String,
              goods_nomenclature_item_id: String,
              validity_start_date: String,
              validity_end_date: nil,
            },
          },
        ].ignore_extra_values!
      end

      it 'renders record attributes' do
        measure = create :measure,
                         :with_measure_type,
                         goods_nomenclature: heading,
                         goods_nomenclature_sid: heading.goods_nomenclature_sid,
                         goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
                         operation_date: Time.zone.today
        measure.destroy
        get :changes, params: { id: chapter }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end
  end
end
