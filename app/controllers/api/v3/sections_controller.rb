module Api
  module V3
    class SectionsController < BaseController
      def index
        sections = Section.eager(:section_note).all
        render json: Api::V3::SectionSerializer.collection(sections)
      end

      def show
        section = Section.where(position: params[:id].to_i).eager(:section_note).take
        raise Sequel::RecordNotFound, "Section #{params[:id]} not found" if section.nil?

        render json: Api::V3::SectionSerializer.new(section).call
      end

      def chapters
        section = Section.where(position: params[:id].to_i).eager(chapters: :chapter_note).take
        raise Sequel::RecordNotFound, "Section #{params[:id]} not found" if section.nil?

        render json: Api::V3::SectionSerializer.chapter_collection(section.chapters)
      end
    end
  end
end
