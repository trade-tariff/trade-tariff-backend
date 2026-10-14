require 'rails_helper'

RSpec.describe GenerateRunLabelWorker, type: :worker do
  let(:run) { create(:evaluation_run) }
  let(:overrides) { { 'retrieval_method' => 'vector' } }

  describe '#perform' do
    context 'when the run still exists' do
      before { allow(Evaluation::RunLabelGenerator).to receive(:call).and_return('vector based retrieval') }

      it 'calls the generator with the run and the launch-time overrides it was enqueued with' do
        described_class.new.perform(run.id, overrides)

        expect(Evaluation::RunLabelGenerator).to have_received(:call).with(have_attributes(id: run.id), overrides)
      end
    end

    context 'when the run has been deleted while the job waited in the queue' do
      before { allow(Evaluation::RunLabelGenerator).to receive(:call) }

      it 'does nothing' do
        expect { described_class.new.perform(999_999, overrides) }.not_to raise_error

        expect(Evaluation::RunLabelGenerator).not_to have_received(:call)
      end
    end

    context 'with the real generator and a fake AI client' do
      let(:ai_client) { instance_double(OpenaiClient, call: { 'label' => 'vector based retrieval' }) }

      before { allow(TradeTariffBackend).to receive(:ai_client).and_return(ai_client) }

      it 'persists the generated label on the run' do
        described_class.new.perform(run.id, overrides)

        expect(run.reload.label).to eq('vector based retrieval')
      end
    end
  end

  describe 'Sidekiq options' do
    it 'runs on the within_1_hour queue, retried like the other LLM fan-outs' do
      expect(described_class.get_sidekiq_options).to include('queue' => :within_1_hour, 'retry' => 3)
    end
  end
end
