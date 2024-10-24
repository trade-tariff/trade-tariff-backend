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

      Api::V2::GreenLanes::CertificatePresenter.wrap(@filtered_certificates, @measure_sid, @group_id_map)
    end

    private

    def group_conditions
      map = condition_permutations.map.with_index do |condition_group, group_id|
        condition_group.permutations.map.with_index do |permutation, permutation_id|
          permutation.measure_conditions.map do |condition|
            {
              condition_id: condition.certificate&.id,
              group_id: group_id + permutation_id,
            }
          end
        end
      end

      # Returns certificate ids with id of permutation group that certificate present
      map&.flat_map { |outer| outer.flat_map { |inner| inner } }
    end

    def filter_certificates(grouped_by_group_id, grouped_by_condition_id)
      certificate_ids = @certificates.map(&:id)

      # Filter out certificates if all certificates in its are not present
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

      # Filter out groups if its certificates are not in CA certificate list
      filtered_groups = grouped_by_group_id.select do |_group_id, condition_ids|
        condition_ids.all? { |condition_id| certificate_ids.include?(condition_id) }
      end

      # Filter out certificates group id, if the group is not completed
      filtered_conditions = grouped_by_condition_id.select do |_condition_id, group_ids|
        group_ids.any? { |group_id| filtered_groups.keys.include?(group_id) }
      end

      # Returns group ids against certificate ids
      @group_id_map = filtered_conditions.transform_values do |group_ids|
        group_ids.select { |group_id| filtered_groups.keys.include?(group_id) }
      end
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
