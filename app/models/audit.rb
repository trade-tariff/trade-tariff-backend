class Audit < Sequel::Model
  many_to_one :auditable, reciprocal: :audits, reciprocal_type: :many_to_one,
                          setter: (proc do |auditable|
                                     self[:auditable_id] = (auditable.pk if auditable)
                                     self[:auditable_type] = (auditable.class.name if auditable)
                                   end),
                          dataset: (proc do
                                      klass = auditable_type.constantize
                                      klass.where(klass.primary_key => auditable_id)
                                    end),
                          eager_loader: (proc do |eo|
                                           id_map = {}
                                           eo[:rows].each do |asset|
                                             asset.associations[:auditable] = nil
                                             ((id_map[asset.auditable_type] ||= {})[asset.auditable_id] ||= []) << asset
                                           end
                                           id_map.each do |klass_name, id_map_value|
                                             klass = klass_name.constantize
                                             klass.where(klass.primary_key => id_map_value.keys).all do |attach|
                                               id_map_value[attach.pk].each do |asset|
                                                 asset.associations[:auditable] = attach
                                               end
                                             end
                                           end
                                         end)

  def before_create
    set_version_number
    set_created_at
    super
  end

  def set_version_number
    max = Audit.where(auditable_id:, auditable_type:).reverse(:version).first.try(:version) || 0
    self.version = max + 1
  end

  def set_created_at
    self.created_at = Time.zone.now
  end
end
