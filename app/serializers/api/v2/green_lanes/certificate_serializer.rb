module Api
  module V2
    module GreenLanes
      class CertificateSerializer
        include JSONAPI::Serializer

        set_id :id

        attribute :code, &:id

        attributes :certificate_type_code,
                   :certificate_code,
                   :description,
                   :formatted_description
      end
    end
  end
end
