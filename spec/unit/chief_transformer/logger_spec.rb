require 'rails_helper'
require 'chief_transformer'

describe ChiefTransformer::Logger do
  describe '#start_transform logging' do
    it 'logs an info event' do
      chief_transformer_logger do
        ChiefTransformer.instance.invoke
        expect(@logger.logged(:info).size).to be >= 1
        expect(@logger.logged(:info).first).to match(/CHIEF Transformer started/)
      end
    end
  end

  describe '#transform logging' do
    context 'transformation with errors' do
      let!(:tame)    { create :tame, :unprocessed }
      let!(:measure) { create :measure }

      it 'logs an error event and sends an error email' do
        allow_any_instance_of(Chief::Tame).to receive(:mark_as_processed!)
          .and_raise(Sequel::ValidationFailed.new(measure))

        chief_transformer_logger do
          expect { ChiefTransformer.instance.invoke }.to raise_error(ChiefTransformer::TransformException)

          expect(@logger.logged(:error).size).to eq 1
          expect(@logger.logged(:error).last).to match(/Could not transform/i)

          expect(ActionMailer::Base.deliveries).not_to be_empty
          email = ActionMailer::Base.deliveries.last
          expect(email.encoded).to match(/invalid CHIEF operation/)
        end
      end
    end
  end

  describe '#process logging' do
    it 'when successful process logs an info event' do
      create :tame
      chief_transformer_logger do
        ChiefTransformer.instance.invoke
        expect(@logger.logged(:info).size).to be >= 1
        expect(@logger.logged(:info)[1]).to match(/processed/i)
      end
    end
  end
end
