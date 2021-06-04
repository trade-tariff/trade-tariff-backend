revision = if File.exist?(Rails.root.join('REVISION'))
             system('cat', Rails.root.join('REVISION')).chomp
           else
             Rails.env
           end

CURRENT_REVISION = revision
