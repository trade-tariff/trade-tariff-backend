module Api
  module Admin
    module VersionBrowsing
      extend ActiveSupport::Concern

      private

      def serializer_options
        { meta: version_meta }
      end

      def version_meta
        {
          version: {
            current: current_version?,
            oid: current_version_id,
            previous_oid: previous_version_id,
            has_previous_version: previous_version_id.present?,
            latest_event: latest_version_event,
          },
        }
      end

      def current_version_id
        @current_version_id ||= viewed_version&.id
      end

      def previous_version_id
        return @previous_version_id if defined?(@previous_version_id)

        viewed_id = viewed_version&.id
        return @previous_version_id = nil if viewed_id.blank?

        @previous_version_id = versions_for_item
          .where(Sequel.lit('id < ?', viewed_id))
          .order(Sequel.desc(:id))
          .get(:id)
      end

      def viewed_version
        @viewed_version ||= if filter_version_id.present?
                              versions_for_item
                                .where(id: filter_version_id)
                                .first
                            else
                              versions_for_item
                                .order(Sequel.desc(:id))
                                .first
                            end
      end

      def current_version?
        return true if filter_version_id.blank?
        return false if latest_version_event == 'destroy'

        filter_version_id == latest_version_id
      end

      def latest_version_id
        @latest_version_id ||= versions_for_item.order(Sequel.desc(:id)).get(:id)
      end

      def latest_version_event
        @latest_version_event ||= versions_for_item.order(Sequel.desc(:id)).get(:event)
      end

      def filter_version_id
        params.dig(:filter, :oid)&.to_i
      end
    end
  end
end
