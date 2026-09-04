module Api
  module V2
    class VatGuidanceDemoController < ApiController
      no_caching

      before_action :ensure_demo_enabled!

      def show
        render json: {
          data: {
            id: 'ai-1146',
            type: 'vat_guidance_demo',
            attributes: VatGuidance::DemoArtifact.new.call,
          },
        }
      end

    private

      def ensure_demo_enabled!
        return if Rails.env.development? || Rails.env.test? || ENV['VAT_GUIDANCE_DEMO_ENABLED'] == 'true'

        head :not_found
      end
    end
  end
end
