module Api
  module Admin
    class FootnotesController < AdminController
      def index
        @footnotes = Footnote.actual.national.eager(:footnote_descriptions).all

        render json: Api::Admin::FootnoteSerializer.new(@footnotes).serializable_hash
      end

      def show
        @footnote = Footnote.national.with_pk!(footnote_pk)

        render json: Api::Admin::FootnoteSerializer.new(@footnote, { is_collection: false }).serializable_hash
      end

      def update
        @footnote = Footnote.national.with_pk!(footnote_pk)

        @description = @footnote.footnote_description
        @description.set(footnote_params[:attributes])

        if @description.save
          render json: Api::Admin::FootnoteSerializer.new(@footnote, { is_collection: false }).serializable_hash
        else
          render json: Api::Admin::ErrorSerializationService.new(@description).call, status: :unprocessable_content
        end
      end

      private

      def footnote_params
        params.require(:data).permit(:type, attributes: [:description])
      end

      def footnote_pk
        [footnote_id[0..1], footnote_id[2, 5]]
      end

      def footnote_id
        params.fetch(:id, '')
      end
    end
  end
end
