module VatGuidance
  class Guide < Sequel::Model(:vat_guides)
    include ImmutableRecord

    plugin :auto_validations, not_null: :presence
    plugin :timestamps

    one_to_many :versions,
                class: 'VatGuidance::GuideVersion',
                key: :guide_id

    def validate
      super
      validates_presence :guide_key
    end
  end
end
