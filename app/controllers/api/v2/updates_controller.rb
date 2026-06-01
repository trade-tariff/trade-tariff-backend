module Api
  module V2
    class UpdatesController < ApiController
      def latest
        last_applied_at = TariffSynchronizer::BaseUpdate.applied.max(:applied_at).to_i
        @updates = Rails.cache.fetch("api/v2/updates/latest/#{TradeTariffBackend.service}/#{last_applied_at}", expires_in: 1.hour) do
          TariffSynchronizer::BaseUpdate.latest_applied_of_both_kinds.all
        end

        render json: Api::V2::TariffUpdateSerializer.new(@updates).serializable_hash
      end
    end
  end
end
