# frozen_string_literal: true

# Historically the Tariff has always supported requests to the commodity endpoint
# for chapters and headings with their full 10 digits as their id value in both V1
# and V2.
#
# This implementation adjusts the path to the /headings or /chapters endpoints
# and uses the short code form for these parts of the hierarchy
class HandleGoodsNomenclature
  CHAPTER_REGEX = /\d{2}0{8}/
  HEADING_REGEX = /\d{4}0{6}/

  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    if path_incorrectly_matches_commodity?(request.path_info)
      transform_path(request)
    end

    status, headers, response = @app.call(env)

    headers['X-Old-Path'] = env['action_dispatch.old-path'] if env['action_dispatch.old-path']
    headers['X-Path-Transformed'] = env['action_dispatch.path-transformed'].to_s

    [status, headers, response]
  end

  private

  def path_incorrectly_matches_commodity?(path)
    return false unless path.include?('commodities')

    if path.match?(CHAPTER_REGEX) || path.match?(HEADING_REGEX)
      return true
    end

    false
  end

  def id_and_type_for(id)
    if id.match?(CHAPTER_REGEX)
      [id[0..1], 'chapters']
    else
      [id[0..3], 'headings']
    end
  end

  def transform_path(request)
    id, type = id_and_type_for(request.path_info.split('/').last)
    old_path = request.path_info.dup

    request.path_info.gsub!(/commodities\/\d{10}/, "#{type}/#{id}")

    request.set_header 'action_dispatch.path-transformed', request.path_info
    request.set_header 'action_dispatch.old-path', old_path
  end
end
