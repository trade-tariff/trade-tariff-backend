module Api
  module V2
    # Temporary alias for frontends still posting to the V2 path.
    # Remove once all frontend releases use the Internal API endpoint.
    class EnquiryForm::SubmissionsController < Api::Internal::EnquiryForm::SubmissionsController; end
  end
end
