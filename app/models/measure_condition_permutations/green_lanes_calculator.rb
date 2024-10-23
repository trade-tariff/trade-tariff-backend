module MeasureConditionPermutations
  class GreenLanesCalculator
    def initialize(measure_conditions, certificates, measure_sid)
      @measure_conditions = measure_conditions
      @certificates = certificates
      @measure_sid = measure_sid
    end

    def group_certificates
      grouped_by_group_id = group_conditions.group_by { |condition| condition[:group_id] }
                                            .transform_values { |conditions| conditions.map { |condition| condition[:condition_id] } }

      grouped_by_condition_id = group_conditions.group_by { |condition| condition[:condition_id] }
                                                .transform_values { |conditions| conditions.map { |condition| condition[:group_id] } }

      filter_certificates(grouped_by_group_id, grouped_by_condition_id)
      filter_groups(grouped_by_group_id, grouped_by_condition_id)

      Api::V2::GreenLanes::CertificatePresenter.wrap(@filtered_certificates, @group_id_map, @measure_sid)
    end

    private

    def group_conditions
      map = condition_permutations.map.with_index do |condition_group, group_id|
        condition_group.permutations.map.with_index do |permutation, permutation_id|
          permutation.measure_conditions.map do |condition|
            {
              condition_id: condition.certificate&.id,
              group_id: group_id + permutation_id
            }
          end
        end
      end

      map&.flat_map { |outer| outer.flat_map { |inner| inner } }
    end

    def filter_certificates(grouped_by_group_id, grouped_by_condition_id)
      certificate_ids = @certificates.map(&:id)

      @filtered_certificates = @certificates.select do |certificate|
        group_ids = grouped_by_condition_id[certificate.id]

        group_ids.any? do |group_id|
          grouped_by_group_id[group_id].all? do |condition_id|
            certificate_ids.include?(condition_id)
          end
        end
      end
    end

    def filter_groups(grouped_by_group_id, grouped_by_condition_id)
      certificate_ids = @filtered_certificates.map(&:id)

      filtered_groups = grouped_by_group_id.select do |group_id, condition_ids|
        condition_ids.all? { |condition_id| certificate_ids.include?(condition_id) }
      end

      filtered_conditions = grouped_by_condition_id.select do |condition_id, group_ids|
        group_ids.any? { |group_id| filtered_groups.keys.include?(group_id) }
      end

      @group_id_map = filtered_conditions.map do |condition_id, group_ids|
        [condition_id, group_ids.select { |group_id| filtered_groups.keys.include?(group_id) }]
      end.to_h
    end

    def condition_permutations
      if matched_measure_conditions?
        Calculators::Matched.new('n/a', @measure_conditions)
                            .permutation_groups
      else
        Calculators::Unmatched.new('n/a', @measure_conditions)
                              .permutation_groups
      end
    end

    def matched_measure_conditions?
      @measure_conditions
        .group_by(&:permutation_key)
        .values
        .any?(&:many?) # multiple conditions with same key
    end
  end
end
