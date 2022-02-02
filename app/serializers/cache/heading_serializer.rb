module Cache
  class HeadingSerializer
    attr_reader :heading

    def initialize(heading)
      @heading = heading
    end

    def as_json
      heading_attributes = {
        id: heading.id,
        goods_nomenclature_sid: heading.goods_nomenclature_sid,
        goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
        producline_suffix: heading.producline_suffix,
        validity_start_date: heading.validity_start_date&.strftime('%FT%T.%LZ'),
        validity_end_date: heading.validity_end_date,
        description: heading.description,
        formatted_description: heading.formatted_description,
        bti_url: heading.bti_url,
        number_indents: heading.number_indents,
      }

      # TODO: Separate intermediate serialization for subheadings
      unless heading.is_a?(Heading)
        heading_attributes[:heading] = {
          id: heading.heading.id,
          goods_nomenclature_sid: heading.heading.goods_nomenclature_sid,
          goods_nomenclature_item_id: heading.heading.goods_nomenclature_item_id,
          description: heading.heading.description,
          formatted_description: heading.heading.formatted_description,
          description_plain: heading.heading.description_plain,
        }
      end

      if heading.chapter.present?
        heading_attributes[:chapter] = {
          id: heading.chapter.id,
          goods_nomenclature_sid: heading.chapter.goods_nomenclature_sid,
          goods_nomenclature_item_id: heading.chapter.goods_nomenclature_item_id,
          producline_suffix: heading.chapter.producline_suffix,
          validity_start_date: heading.chapter.validity_start_date&.strftime('%FT%T.%LZ'),
          validity_end_date: heading.chapter.validity_end_date,
          description: heading.chapter.description,
          formatted_description: heading.chapter.formatted_description,
          chapter_note: heading.chapter.chapter_note&.content,
          forum_link: {
            url: heading.chapter.forum_link&.url,
          },
          guide_ids: heading.chapter.guides.map(&:id),
          guides: heading.chapter.guides.map do |guide|
            {
              id: guide.id,
              title: guide.title,
              url: guide.url,
            }
          end,
        }
      end

      heading_attributes[:section_id] = heading.section&.id

      if heading.section.present?
        heading_attributes[:section] = {
          id: heading.section.id,
          numeral: heading.section.numeral,
          title: heading.section.title,
          position: heading.section.position,
          section_note: heading.section.section_note&.content,
        }
      end

      heading_attributes[:footnotes] = heading.footnotes.map do |footnote|
        {
          footnote_id: footnote.footnote_id,
          validity_start_date: footnote.validity_start_date&.strftime('%FT%T.%LZ'),
          validity_end_date: footnote.validity_end_date,
          code: footnote.code,
          description: footnote.description,
          formatted_description: footnote.formatted_description,
        }
      end

      heading_attributes[:commodities] = heading.commodities.map do |commodity|
        commodity_attributes = {
          id: commodity.id,
          goods_nomenclature_sid: commodity.goods_nomenclature_sid,
          goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
          validity_start_date: commodity.validity_start_date&.strftime('%FT%T.%LZ'),
          validity_end_date: commodity.validity_end_date,
        }

        commodity_attributes[:goods_nomenclature_indents] = commodity.goods_nomenclature_indents.map do |goods_nomenclature_indent|
          {
            goods_nomenclature_indent_sid: goods_nomenclature_indent.goods_nomenclature_indent_sid,
            validity_start_date: goods_nomenclature_indent.validity_start_date&.strftime('%FT%T.%LZ'),
            validity_end_date: goods_nomenclature_indent.validity_end_date,
            number_indents: goods_nomenclature_indent.number_indents,
            productline_suffix: goods_nomenclature_indent.productline_suffix,
          }
        end

        commodity_attributes[:goods_nomenclature_descriptions] = commodity.goods_nomenclature_descriptions.map do |goods_nomenclature_description|
          {
            goods_nomenclature_description_period_sid: goods_nomenclature_description.goods_nomenclature_description_period_sid,
            validity_start_date: goods_nomenclature_description.validity_start_date&.strftime('%FT%T.%LZ'),
            validity_end_date: goods_nomenclature_description.validity_end_date,
            description: goods_nomenclature_description.description,
            formatted_description: DescriptionFormatter.format(value: goods_nomenclature_description.description),
            description_plain: DescriptionTrimFormatter.format(value: goods_nomenclature_description.description),
          }
        end

        commodity_attributes[:overview_measures] = commodity.overview_measures.map do |measure|
          {
            measure_sid: measure.measure_sid,
            effective_start_date: measure.effective_start_date&.strftime('%FT%T.%LZ'),
            effective_end_date: measure.effective_end_date&.strftime('%FT%T.%LZ'),
            goods_nomenclature_sid: measure.goods_nomenclature_sid,
            vat: measure.vat?,
            duty_expression_id: "#{measure.measure_sid}-duty_expression",
            duty_expression: {
              id: "#{measure.measure_sid}-duty_expression",
              base: measure.duty_expression_with_national_measurement_units_for(commodity),
              formatted_base: measure.formatted_duty_expression_with_national_measurement_units_for(commodity),
            },
            measure_type_id: measure.measure_type.measure_type_id,
            measure_type: {
              measure_type_id: measure.measure_type.measure_type_id,
              description: measure.measure_type.description,
            },
          }
        end
        commodity_attributes
      end

      heading_attributes
    end
  end
end
