namespace :importer do
  namespace :xi_cn do
    desc 'Reimport XI CN notes for a specific version, or all non-failed versions if none given'
    task :reimport, [:version] => :environment do |_, args|
      XiCnImporter::Reimporter.new.call(version: args[:version].presence)
    end
  end
end
