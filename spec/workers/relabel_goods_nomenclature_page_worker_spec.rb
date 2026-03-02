RSpec.describe RelabelGoodsNomenclaturePageWorker, type: :worker do
  describe '#perform' do
    let(:page_number) { 1 }
    let!(:commodity) { create(:commodity) }

    let(:ai_response) do
      {
        'data' => [
          {
            'commodity_code' => commodity.goods_nomenclature_item_id,
            'description' => 'Pure-bred breeding horses for equestrian purposes',
            'known_brands' => %w[Thoroughbred Arabian],
            'colloquial_terms' => ['stud horses', 'breeding stock'],
            'synonyms' => ['purebred horses', 'pedigree horses'],
            'original_description' => commodity.description,
          },
        ],
      }
    end

    let(:label) do
      GoodsNomenclatureLabel.build(
        commodity,
        ai_response['data'].first,
      )
    end

    let(:label_service) do
      instance_double(
        LabelService,
        call: [label],
        last_ai_response: ai_response,
      )
    end

    let(:label_confidence_scorer) { instance_double(LabelConfidenceScorer, score: nil) }

    before do
      TradeTariffRequest.time_machine_now = Time.current

      allow(LabelService).to receive(:new).and_return(label_service)
      allow(GoodsNomenclatureSelfText).to receive(:regenerate_search_embeddings)
      allow(LabelConfidenceScorer).to receive(:new).and_return(label_confidence_scorer)
    end

    it 'calls LabelService with the batch and page number' do
      described_class.new.perform(page_number)

      expect(LabelService).to have_received(:new) do |batch, **options|
        expect(batch.size).to eq(1)
        expect(options[:page_number]).to eq(page_number)
      end
    end

    it 'regenerates search embeddings for the batch' do
      described_class.new.perform(page_number)

      expect(GoodsNomenclatureSelfText).to have_received(:regenerate_search_embeddings)
        .with([commodity.goods_nomenclature_sid])
    end

    it 'scores labels for the batch' do
      described_class.new.perform(page_number)

      expect(label_confidence_scorer).to have_received(:score)
        .with([commodity.goods_nomenclature_sid])
    end

    context 'when label is valid' do
      it 'saves the label to the database' do
        expect { described_class.new.perform(page_number) }
          .to change(GoodsNomenclatureLabel, :count).by(1)
      end

      it 'instruments label_saved' do
        allow(LabelGenerator::Instrumentation).to receive(:page_started)
        allow(LabelGenerator::Instrumentation).to receive(:page_completed).and_call_original
        allow(LabelGenerator::Instrumentation).to receive(:label_saved)

        described_class.new.perform(page_number)

        expect(LabelGenerator::Instrumentation).to have_received(:label_saved).with(
          label,
          page_number:,
        )
      end

      it 'instruments page completion with correct counts' do
        allow(LabelGenerator::Instrumentation).to receive(:page_started)
        allow(LabelGenerator::Instrumentation).to receive(:page_completed).and_call_original
        allow(LabelGenerator::Instrumentation).to receive(:label_saved)

        described_class.new.perform(page_number)

        expect(LabelGenerator::Instrumentation).to have_received(:page_completed) do |**args, &_block|
          expect(args[:page_number]).to eq(page_number)
        end
      end
    end

    context 'when label fails validation' do
      let(:invalid_label) do
        GoodsNomenclatureLabel.new(
          goods_nomenclature: commodity,
          labels: nil, # missing required field
        )
      end

      let(:label_service) do
        instance_double(
          LabelService,
          call: [invalid_label],
          last_ai_response: ai_response,
        )
      end

      it 'does not save the label' do
        expect { described_class.new.perform(page_number) }
          .not_to change(GoodsNomenclatureLabel, :count)
      end

      it 'instruments label_save_failed with validation errors' do
        allow(LabelGenerator::Instrumentation).to receive(:page_started)
        allow(LabelGenerator::Instrumentation).to receive(:page_completed).and_call_original
        allow(LabelGenerator::Instrumentation).to receive(:label_save_failed)

        described_class.new.perform(page_number)

        expect(LabelGenerator::Instrumentation).to have_received(:label_save_failed) do |failed_label, error, **options|
          expect(failed_label).to eq(invalid_label)
          expect(error).to be_a(Sequel::ValidationFailed)
          expect(options[:page_number]).to eq(page_number)
        end
      end

      it 'does not raise an exception' do
        expect { described_class.new.perform(page_number) }.not_to raise_error
      end
    end

    context 'when label already exists' do
      before do
        create(:goods_nomenclature_label, goods_nomenclature: commodity)
      end

      it 'excludes the commodity from the batch (already labeled)' do
        described_class.new.perform(page_number)

        expect(LabelService).not_to have_received(:new)
      end

      it 'does not create any new labels' do
        expect { described_class.new.perform(page_number) }
          .not_to change(GoodsNomenclatureLabel, :count)
      end
    end

    context 'when page processing fails entirely' do
      let(:label_service) do
        service = instance_double(LabelService, last_ai_response: ai_response)
        allow(service).to receive(:call).and_raise(StandardError, 'API timeout')
        service
      end

      it 'instruments page_failed with error and AI response' do
        allow(LabelGenerator::Instrumentation).to receive(:page_started)
        allow(LabelGenerator::Instrumentation).to receive(:page_failed)

        expect { described_class.new.perform(page_number) }.to raise_error(StandardError, 'API timeout')

        expect(LabelGenerator::Instrumentation).to have_received(:page_failed).with(
          page_number:,
          error: an_instance_of(StandardError),
          ai_response:,
        )
      end

      it 're-raises the exception for Sidekiq retry' do
        allow(LabelGenerator::Instrumentation).to receive(:page_started)
        allow(LabelGenerator::Instrumentation).to receive(:page_failed)

        expect { described_class.new.perform(page_number) }.to raise_error(StandardError)
      end
    end

    context 'with empty batch' do
      before do
        allow(GoodsNomenclatureLabel).to receive(:goods_nomenclatures_dataset)
          .and_return(GoodsNomenclature.where(Sequel.lit('1=0')))
      end

      it 'returns early without processing' do
        described_class.new.perform(page_number)

        expect(LabelService).not_to have_received(:new)
      end
    end

    context 'with multiple labels (mixed success and failure)' do
      let(:commodity2) { create(:commodity) }

      let(:valid_label) do
        GoodsNomenclatureLabel.build(commodity, ai_response['data'].first)
      end

      let(:invalid_label) do
        GoodsNomenclatureLabel.new(
          goods_nomenclature: commodity2,
          labels: nil,
        )
      end

      let(:label_service) do
        instance_double(
          LabelService,
          call: [valid_label, invalid_label],
          last_ai_response: ai_response,
        )
      end

      it 'saves valid labels and skips invalid ones' do
        expect { described_class.new.perform(page_number) }
          .to change(GoodsNomenclatureLabel, :count).by(1)
      end

      it 'instruments both success and failure' do
        allow(LabelGenerator::Instrumentation).to receive(:page_started)
        allow(LabelGenerator::Instrumentation).to receive(:page_completed).and_call_original
        allow(LabelGenerator::Instrumentation).to receive(:label_saved)
        allow(LabelGenerator::Instrumentation).to receive(:label_save_failed)

        described_class.new.perform(page_number)

        expect(LabelGenerator::Instrumentation).to have_received(:label_saved).once
        expect(LabelGenerator::Instrumentation).to have_received(:label_save_failed).once
      end
    end
  end
end
