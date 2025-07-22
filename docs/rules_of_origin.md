# How to update the Rules of Origin (RoO)

## Rules of Origin API

The primary API endpoint for rules of origin is

```
/api/rules_of_origin_schemes/<commodity_code>/<country_code>
```

This will return a JSON-API response containing a list of all applicable schemes and their rules which are relevant to the `commodity_code`

There are also;

```
/api/rules_of_origin_schemes/<commodity_code>
```

Returning the rules across all schemes for a commodity code, the json format for the schemes themselves is reduced to exclude heavier elements like articles markdown

```
/api/rules_of_origin_schemes
```

This returns a listing of all schemes, again with reduced information. This api supports filtering, - at present the only filter is `?filter[has_article]=<article_name>` which will filter the schemes for only those which have the required article.

This endpoint also supports optional `includes` params. Currently the only include supported is proofs, eg `?include=proofs`

The schemes data returned includes both V1 rules, and where available, v2 rulesets. Currently V2 data is available for UK but not XI.

## RoO Data sources

The RoO data files are held in `/lib/rules_of_origin` within this codebase. All data is read into ActiveModel data objects held in memory and connnected via an instance of `RulesOfOrigin::DataSet`

The loaded data is globally available within the running app at `TradeTariffBackend.rules_of_origin` and can be queried using an instance of `RulesOfOrigin::Query`.

### Schemes

- `roo_schemes_uk.json`

  List of RoO schemes for the UK plus data associated with those schemes such as which countries the apply to

- `roo_schemes_xi.json`

  List of RoO schemes for XI

Both of these JSON files are loaded into ActiveModel objects under `db/models/rules_of_origin`. If new keys are added to the schemes JSON which you don't which to parse, you'll need to add stub setter methods to `RulesOfOrigin::Scheme`, eg `def some_attr=(_v); end`

### V1 rules

V1 rules are the old data set, currently available for both UK and XI.

The data is held in large CSVs with frequent duplication of strings. These CSVs are read into memory and they rely on the use of frozen string literals in the ActiveModel objects to reduce memory usage to a sensible level.

- `rules_of_origin_xxxxxx.csv`

  containing V1 rules of origin data

- `rules_to_commodities_xxxxxx.csv`

  Containing the mapping between V1 rules and commodities

### V2 rules

V2 Rules data is held in JSON files rather than CSVs

```
/roo_schemes_uk/rule_sets/<scheme_code>.json
```

and for Northern Ireland

```
/roo_schemes_xi/rule_sets/<scheme_code>.json
```

### Other schemes data

There are additional markdown files included within the Schemes API. These are held in the following folders, included within the API and rendered in the frontend UI:

```
/roo_schemes_uk/fta_intro/
/roo_schemes_uk/introductory_notes/
/roo_schemes_uk/articles/<scheme_code>/<article_name>
```

for Northern Ireland,

```
/roo_schemes_xi/fta_intro/
/roo_schemes_xi/introductory_notes/
/roo_schemes_xi/articles/<scheme_code>/<article_name>
```

## How to validate the RoO data files

Two rake tasks are available to validate the RoO files:

```bash
rake rules_of_origin:validate_mappings          # validate a CSV mappings file - CSVFILE=path/to/file.csv
rake rules_of_origin:validate_rules             #  file - CSVFILE=path/to/file.csv
```

Additionally there are RSpec tests which can be run against the datasets, these are not part of the default test run but can be run as follows

```bash
bundle exec rspec --tag roo_data
```

These specs are run automatically by CI whenever there are any changes affecting the `/lib/rules_of_origin` folder

## Steps to update the RoO data files

-[] copy the CSV, json, and md files in the relevant folders (see file structure above)
-[] check the validity of the csv files using the rake tasks, for example:
  `bundle exec rake rules_of_origin:validate_mappings CSVFILE=lib/rules_of_origin/rules_to_commodities_211124.csv`
  and
  `bundle exec rake rules_of_origin:validate_rules CSVFILE=lib/rules_of_origin/rules_of_origin_211124.csv`

  these returns Success/Failure message

-[] remove possible old files. The name of those are similar to the new ones, and only the date is different.
-[] update the constant *DEFAULT_FILE* on `heading_mappings.rb` and `rule_set.rb`
-[] Any articles/markdown files/v2 rules can be updated by just replacing the files in the repository and using `git diff` to check there are only the changes you expect
