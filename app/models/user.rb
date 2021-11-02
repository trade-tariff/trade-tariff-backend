class User < Sequel::Model
  include GDS::SSO::User

  plugin :serialization

  serialize_attributes :yaml, :permissions

  module Permissions
    SIGNIN = 'signin'.freeze
    HMRC_EDITOR = 'HMRC Editor'.freeze
    GDS_EDITOR = 'GDS Editor'.freeze
  end

  def self.find_for_gds_oauth(auth_hash)
    user_params = user_params_from_auth_hash(auth_hash)

    # update details of existing user
    if (user = find(uid: auth_hash['uid']))
      user.update_attributes(user_params)
    else # Create a new user.
      create(user_params)
    end
  end

  def self.user_params_from_auth_hash(auth_hash)
    GDS::SSO::User.user_params_from_auth_hash(auth_hash.to_hash)
  end

  def self.find_by_uid(uid)
    find(uid: uid)
  end

  def self.create!(attrs)
    create(attrs)
  end

  def gds_editor?
    has_permission?(Permissions::GDS_EDITOR)
  end

  def hmrc_editor?
    has_permission?(Permissions::HMRC_EDITOR)
  end

  def remotely_signed_out?
    remotely_signed_out
  end

  def disabled?
    disabled
  end

  def update!(options)
    options.each do |key, value|
      # rubocop:disable Rails/SkipsModelValidations
      update_attribute(key, value)
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  def update_attribute(attribute, value)
    update(attribute => value)
  end

  def update_attributes(attributes)
    update(attributes)
    self
  end

  # ActiveRecord compatibility - #save! is called when automatically creating
  # a mock user
  def save!
    save || raise(Sequel::Error, 'Failed to save the record')
  end
end
