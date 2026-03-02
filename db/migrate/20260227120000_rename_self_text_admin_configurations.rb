Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      renames = {
        'self_text_context' => 'other_self_text_context',
        'self_text_model' => 'other_self_text_model',
        'self_text_batch_size' => 'other_self_text_batch_size',
      }

      renames.each do |old_name, new_name|
        next if from(:uk__admin_configurations_oplog).where(name: new_name).any?
        next unless from(:uk__admin_configurations_oplog).where(name: old_name).any?

        from(:uk__admin_configurations_oplog)
          .where(name: old_name)
          .update(name: new_name)
      end
    end
  end

  down do
    if TradeTariffBackend.uk?
      renames = {
        'other_self_text_context' => 'self_text_context',
        'other_self_text_model' => 'self_text_model',
        'other_self_text_batch_size' => 'self_text_batch_size',
      }

      renames.each do |old_name, new_name|
        next if from(:uk__admin_configurations_oplog).where(name: new_name).any?
        next unless from(:uk__admin_configurations_oplog).where(name: old_name).any?

        from(:uk__admin_configurations_oplog)
          .where(name: old_name)
          .update(name: new_name)
      end
    end
  end
end
