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

        attribute :group_ids do |object|
          object.group_ids if object.is_a?(CertificatePresenter)
        end

        attribute :code do |object|
          if object.is_a?(CertificatePresenter)
            object.certificate_id
          else
            object.id
          end
        end
      end
    end
  end
end
