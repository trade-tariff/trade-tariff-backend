class CachedCommodityService
  class ResponseFilter
    def initialize(cached_data, geographical_area_id)
      @hash = deep_dup(cached_data[:hash])
      @measure_meta = cached_data[:measure_meta]
      @geographical_area_id = geographical_area_id
    end

    def call
      return @hash if @geographical_area_id.blank?

      filter_measures
      update_relationship_arrays
      recompute_commodity_attributes
      recompute_duty_calculator_meta
      recompute_preference_codes
      recompute_import_trade_summary
      clean_up_included
      @hash
    end

    private

    attr_reader :measure_meta, :geographical_area_id

    def filter_measures
      @surviving_sids = measure_meta.select { |_sid, meta|
        relevant?(meta, geographical_area_id)
      }.keys.to_set

      @surviving_import_meta = measure_meta.select do |sid, meta|
        @surviving_sids.include?(sid) && meta[:import]
      end

      @surviving_export_meta = measure_meta.select do |sid, meta|
        @surviving_sids.include?(sid) && meta[:export]
      end
    end

    def relevant?(meta, country_id)
      return false if meta[:excluded_geographical_area_ids].include?(country_id)
      return true if meta[:erga_omnes] && meta[:national]
      return true if meta[:erga_omnes] && meta[:meursing_type]
      return true if meta[:geographical_area_id].blank? || meta[:geographical_area_id] == country_id

      meta[:contained_geographical_area_ids].include?(country_id)
    end

    def update_relationship_arrays
      data = @hash[:data]
      rels = data[:relationships]

      rels[:import_measures][:data]&.select! { |ref| @surviving_sids.include?(ref[:id].to_i) }
      rels[:export_measures][:data]&.select! { |ref| @surviving_sids.include?(ref[:id].to_i) }
    end

    def recompute_commodity_attributes
      attrs = @hash[:data][:attributes]

      third_country = @surviving_import_meta.select { |_, m| m[:third_country] }

      attrs[:basic_duty_rate] = if third_country.size == 1
                                  third_country.values.first[:formatted_duty_expression]
                                end

      attrs[:meursing_code] = @surviving_import_meta.any? { |_, m| m[:meursing] }
    end

    def recompute_duty_calculator_meta
      meta = @hash[:data][:meta][:duty_calculator]

      third_country = @surviving_import_meta.select { |_, m| m[:third_country] }
      meta[:zero_mfn_duty] = third_country.any? && third_country.all? { |_, m| m[:zero_mfn] }
      meta[:trade_defence] = @surviving_import_meta.any? { |_, m| m[:trade_remedy] }
      meta[:entry_price_system] = TradeTariffBackend.xi? && @surviving_import_meta.any? { |_, m| m[:entry_price_system] }
      meta[:meursing_code] = @surviving_import_meta.any? { |_, m| m[:meursing] }
      meta[:applicable_additional_codes] = recompute_additional_codes
      meta[:applicable_measure_units] = recompute_measure_units
      meta[:applicable_vat_options] = recompute_vat_options
    end

    def recompute_additional_codes
      codes = {}

      @surviving_import_meta.each do |sid, meta|
        contrib = meta[:additional_code_contribution]
        if contrib
          mt_id = contrib[:measure_type_id]
          codes[mt_id] ||= {
            'measure_type_description' => contrib[:measure_type_description],
            'heading' => contrib[:heading],
            'additional_codes' => [],
          }
          codes[mt_id]['additional_codes'] << contrib[:code_annotation]
        end

        # Add "none option" for measure types where a measure without additional code survives
        next unless meta[:has_no_additional_code]

        mt_id = meta[:measure_type_id]
        next unless codes.key?(mt_id)

        none_annotation = {
          'code' => 'none',
          'overlay' => 'No additional code',
          'hint' => '',
          'geographical_area_id' => meta[:geographical_area_id],
          'measure_sid' => sid,
        }
        codes[mt_id]['additional_codes'] << none_annotation
      end

      codes
    end

    def recompute_measure_units
      units = @surviving_import_meta.each_with_object([]) do |(_, meta), arr|
        next unless meta[:measure_unit_contributions]

        arr.concat(meta[:measure_unit_contributions])
      end

      units.each_with_object({}) do |unit, acc|
        unit_code = unit[:measurement_unit_code]
        unit_qualifier_code = unit[:measurement_unit_qualifier_code]
        unit_key = "#{unit_code}#{unit_qualifier_code}"

        MeasurementUnit.units(unit_code, unit_key).each do |presented_unit|
          key = "#{presented_unit['measurement_unit_code']}#{presented_unit['measurement_unit_qualifier_code']}"
          acc[key] = presented_unit
        end
      end
    end

    def recompute_vat_options
      @surviving_import_meta.each_with_object({}) do |(_, meta), acc|
        contrib = meta[:vat_option_contribution]
        next unless contrib

        acc[contrib[:key]] = contrib[:description]
      end
    end

    def recompute_preference_codes
      authorised_use_provisions_submission = @surviving_import_meta.any? do |_, m|
        m[:authorised_use_provisions_submission]
      end

      special_nature_any = @surviving_import_meta.any? { |_, m| m[:special_nature] }

      declarable_proxy = DeclarableProxy.new(authorised_use_provisions_submission, special_nature_any)

      @surviving_import_meta.each do |sid, meta|
        measure_proxy = MeasureProxy.new(meta)
        code = PreferenceCode.determine_code(declarable_proxy, measure_proxy)
        next if code.blank?

        preference_code = PreferenceCode[code]
        next unless preference_code

        update_measure_preference_code(sid, preference_code)
      end
    end

    def update_measure_preference_code(measure_sid, preference_code)
      # Find the measure in included
      measure_entry = @hash[:included]&.find do |entry|
        entry[:type] == :measure && entry[:id].to_i == measure_sid
      end
      return unless measure_entry

      old_pref_ref = measure_entry.dig(:relationships, :preference_code, :data)

      # Update reference
      measure_entry[:relationships][:preference_code][:data] = {
        id: preference_code.id,
        type: :preference_code,
      }

      # Remove old preference_code entry from included if no other measure references it
      if old_pref_ref
        remove_orphaned_preference_code(old_pref_ref[:id])
      end

      # Add or update preference_code entry in included
      existing = @hash[:included].find { |e| e[:type] == :preference_code && e[:id] == preference_code.id }
      unless existing
        @hash[:included] << {
          id: preference_code.id,
          type: :preference_code,
          attributes: { code: preference_code.code, description: preference_code.description },
        }
      end
    end

    def remove_orphaned_preference_code(pref_id)
      still_referenced = @hash[:included]&.any? do |entry|
        entry[:type] == :measure &&
          entry.dig(:relationships, :preference_code, :data, :id) == pref_id
      end
      return if still_referenced

      @hash[:included]&.reject! { |e| e[:type] == :preference_code && e[:id] == pref_id }
    end

    def recompute_import_trade_summary
      third_country_erga = @surviving_import_meta.select { |_, m| m[:third_country] && m[:erga_omnes] }
      tariff_pref = @surviving_import_meta.select { |_, m| m[:tariff_preference] }
      pref_quota = @surviving_import_meta.select { |_, m| m[:preferential_quota] }

      basic_third_country_duty = third_country_erga.size == 1 ? third_country_erga.values.first[:formatted_duty_expression] : nil
      preferential_tariff_duty = tariff_pref.size == 1 ? tariff_pref.values.first[:formatted_duty_expression] : nil
      preferential_quota_duty = pref_quota.size == 1 ? pref_quota.values.first[:formatted_duty_expression] : nil

      # Build new content-addressable id
      content = [basic_third_country_duty, preferential_tariff_duty, preferential_quota_duty].map(&:to_s).join("\n")
      new_id = Digest::MD5.hexdigest(content)

      # Update the relationship reference
      @hash[:data][:relationships][:import_trade_summary][:data] = { id: new_id, type: :import_trade_summary }

      # Replace or update the import_trade_summary entry in included
      @hash[:included]&.reject! { |e| e[:type] == :import_trade_summary }
      @hash[:included] << {
        id: new_id,
        type: :import_trade_summary,
        attributes: {
          basic_third_country_duty: basic_third_country_duty,
          preferential_tariff_duty: preferential_tariff_duty,
          preferential_quota_duty: preferential_quota_duty,
        },
      }
    end

    def clean_up_included
      return unless @hash[:included]

      # Remove non-surviving measures
      @hash[:included].select! do |entry|
        if entry[:type].to_s == 'measure'
          @surviving_sids.include?(entry[:id].to_i)
        else
          true
        end
      end

      # BFS from root data relationships to find all reachable included entries.
      # This removes orphaned measure children (conditions, footnotes, geo areas, etc.)
      # that were only referenced by filtered-out measures.
      reachable = compute_reachable_ids

      @hash[:included].select! do |entry|
        reachable.include?([entry[:type].to_s, entry[:id].to_s])
      end
    end

    def compute_reachable_ids
      by_key = {}
      @hash[:included].each do |entry|
        by_key[[entry[:type].to_s, entry[:id].to_s]] = entry
      end

      reachable = Set.new
      queue = []

      # Seed from top-level data relationships
      enqueue_relationships(@hash[:data][:relationships], reachable, queue, by_key)

      # BFS: each reachable entry's relationships can reach further entries
      while (key = queue.shift)
        entry = by_key[key]
        next unless entry&.dig(:relationships)

        enqueue_relationships(entry[:relationships], reachable, queue, by_key)
      end

      reachable
    end

    def enqueue_relationships(relationships, reachable, queue, by_key)
      return unless relationships

      relationships.each_value do |rel|
        rel_data = rel[:data]
        next unless rel_data

        refs = rel_data.is_a?(Array) ? rel_data : [rel_data]
        refs.each do |d|
          key = [d[:type].to_s, d[:id].to_s]
          next if reachable.include?(key)

          reachable.add(key)
          queue << key if by_key.key?(key)
        end
      end
    end

    def deep_dup(obj)
      case obj
      when Hash
        obj.transform_values { |v| deep_dup(v) }
      when Array
        obj.map { |v| deep_dup(v) }
      else
        obj
      end
    end

    # Lightweight proxy objects for preference code evaluation
    class DeclarableProxy
      def initialize(authorised_use_provisions_submission, special_nature)
        @authorised_use_provisions_submission = authorised_use_provisions_submission
        @special_nature = special_nature
      end

      def authorised_use_provisions_submission?
        @authorised_use_provisions_submission
      end

      def special_nature?(_measure)
        @special_nature
      end
    end

    class MeasureProxy
      def initialize(meta)
        @meta = meta
      end

      def authorised_use?
        @meta[:authorised_use]
      end

      def gsp_or_dcts?
        @meta[:gsp_or_dcts]
      end

      def measure_type_id
        @meta[:measure_type_id]
      end
    end
  end
end
