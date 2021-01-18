namespace :data_import do
  # bin/rails "data_import:import_hjid_to_geographical_area_memberships[hjid_member_map.csv]"
  desc 'Import hjid data from source file to geographical_area_memberships_oplog table'
  task :import_hjid_to_geographical_area_memberships, [:filename] => [:environment] do |_task, args|
    # This is a one off task, so it can be ran locally pointing against the target DB using CF conduit
    unless (filename = args[:filename]).present?
      print 'No source file provided'
      exit(false)
    end

    print "Importing hjid data from #{filename}...\n"
    importer = GeographicalAreaMembershipsImportService.new
    importer.import_hjids(filename)

    print "\nResults:\n#{importer.import_hjids_stats}"
  end
end
