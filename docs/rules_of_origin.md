# How to update the Rules of Origin (RoO)


## RoO file structure

The RoO files are placed in `/db/rules_of_origin`.
They are named:

- rules_of_origin_xxxxxx.csv
  containing rules of origin data

- rules_to_commodities_xxxxxx.csv
  Containing the mapping of rules and commodities

- roo_schemes_uk.json
  Is the json scheme of the UK RoO

- roo_schemes_xi.json
  Is the JSON scheme of the Northern Ireland RoO


The following folders contain markdown docs what are rendered in the UI:

`/roo_schemes_uk/fta_intro/`
`/roo_schemes_uk/introductory_notes/`

for the UK, and

`/roo_schemes_xi/fta_intro/`
`/roo_schemes_xi/introductory_notes/`

for Northern Ireland

## How to validate the RoO
Two rake tasks are available to validate the RoO files:

rake rules_of_origin:validate_mappings          # validate a CSV mappings file - CSVFILE=path/to/file.csv
rake rules_of_origin:validate_rules             #  file - CSVFILE=path/to/file.csv


## Steps to update the RoO

-[] copy the CSV, json, and md files in the relevant folders (see file structure above)
-[] check the validity of the csv files using the rake taskes, for example:
  `bundle exec rake rules_of_origin:validate_mappings CSVFILE=db/rules_of_origin/rules_to_commodities_211124.csv`
  and
  `bundle exec rake rules_of_origin:validate_rules CSVFILE=db/rules_of_origin/rules_of_origin_211124.csv`

  these returns Success/Failure message

-[] remove possible old files. The name of those are similar to the new ones, and only the date is different.
-[] update the constant *DEFAULT_FILE* on `heading_mappings.rb` and `rule_set.rb`
