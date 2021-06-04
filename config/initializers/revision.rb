require 'open3'

revision_file = Rails.root.join('REVISION').to_s

revision = if File.exist?(revision_file)
             stdout, _status = Open3.capture2e('cat', revision_file)
             stdout.chomp
           else
             Rails.env
           end

CURRENT_REVISION = revision
