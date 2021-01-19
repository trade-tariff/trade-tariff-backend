require 'rails_helper'

RSpec.describe GaTrackingHelper do
  describe '#track_event' do
    it 'sends the correct props to the TrackingService' do
      tracking_service = instance_spy(TrackingService)
      allow(TrackingService).to receive(:new).and_return(tracking_service)
      allow(I18n).to receive(:t).with(:commodity, scope: 'events').and_return('Clicked')

      helper.track_event(
        :commodity,
        '112300049'
      )

      expect(tracking_service).to have_received(:track_events).with(
        props:
        [
          {
            key: :commodity,
            label: 'Clicked',
            value: '112300049'
          }
        ]
      )
    end
  end

  describe '#track_events' do
    it 'sends the correct props to the TrackingService' do
      tracking_service = instance_spy(TrackingService)
      allow(TrackingService).to receive(:new).and_return(tracking_service)
      allow(I18n).to receive(:t).with(:commodity, scope: 'events').and_return('Clicked')

      helper.track_events(
        [
          {
            key: :event_key_1,
            label: 'Commodity clicked',
            value: '111111'
          },
          {
            key: :event_key_2,
            label: 'Commodity clicked',
            value: '2222222'
          }
        ]
      )

      expect(tracking_service).to have_received(:track_events).with(
        props:
        [
          {
            key: :event_key_1,
            label: 'Commodity clicked',
            value: '111111'
          },
          {
            key: :event_key_2,
            label: 'Commodity clicked',
            value: '2222222'
          }
        ]
      )
    end
  end
end
