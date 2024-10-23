module Api
  module V2
    module GreenLanes
      class CertificatePresenter < WrapDelegator
        include ContentAddressableId

        content_addressable_fields :measure_id,
                                   :certificate_id


        def initialize(certificate, filtered_group_ids = [], measure_id)
          super(certificate)
          @filtered_group_ids = filtered_group_ids
          @measure_id = measure_id
        end

        def measure_id
          @measure_id
        end

        def group_ids
          @filtered_group_ids[certificate_id]
        end

        def certificate_id
          "#{certificate_type_code}#{certificate_code}"
        end
      end
    end
  end
end
