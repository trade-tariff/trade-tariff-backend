# Goods Nomenclature Nested Set

## Tariff Data

The Tariff data we receive from CDS or Taric contains an ordered list of all Goods Nomenclatures. The order is determined by the concatenation of their `goods_nomenclature_item_id` and their `producline_suffix`. Commodities position within the logical hierarchy is determined by any given commodities indentation. This data is held in a second table called `goods_nomenclatures_indents` - these indicate the depth of nesting of the Goods Nomenclatures they belong to, eg

```
0100000000-80 # Indent 0
- 0101000000-80 # Indent 0
- - 0101010000-10 # Indent 1
- - - 0101010000-80 # Indent 2, note: item_id matches parent but suffix is higher
- - - 0101010001-80 # Indent 2
- - 0101010100-80 # Indent 1
```

## A classic Nested Set model

The [Nested Set model](https://en.wikipedia.org/wiki/Nested_set_model) page on wikipedia explains this well.

A Nested Set assumes an ordered identifier for records within the hierarchical database table.

Those records hold left + right (or start + end) values defining a range exclusively containing the identifiers of descendent records within the hierarchy.

Depth within the hierarchy must be dynamically computed by determining ancestors for a record. Ancestors are any other records whose own range fully encompasses the range (left + right) of the target record.

## Reading the data

The Tariff data's hierarchy can be thought of as a modified form of that Nested Set model.

* The data is an ordered list of identifiers (item_id + suffix)
* The 'start of range' value (or 'left') is defined as a records identifier + 1
* We do not need to compute depth, that is provided by the indents table
* The 'end of range' value is 1 less then the lowest identifier which has the same depth as the origin record, and which is greater than the records own identifier.

Descendants and Ancestors can be fetched non-recursively by implementing the above rules.

## Tree Nodes materialized view

To facilitate fast retrieval of data, a `goods_nomenclature_tree_nodes` materialized view is added as a facade in front of the existing indents table. This provides an indexable ordered identifier (called `position`) for all goods nomenclatures which can be used for efficient `JOIN`-ing.

There are 3 key changes in this `tree_nodes` view relative to the `goods_nomenclature_indents` db view sitting behind it.

1. Added a `position` column - this is a string concatenation of the 10 digit `goods_nomenclature_item_id` and the 2 digit `producline_suffix` - then cast to an integer. The rationale behind this is -;
    1. it provides an ordered identifier, that follows the correct sequence of the dataset.
    2. it does not need to preserve the original information, it just needs to maintain the same order
    3. it is a single field allowing for easy use of MAX/MIN sql operators
    4. it is an integer for index performance - in initial prototyping this was a string because the source fields are strings but it was found queries were 4x faster when cast to an integer. Using a decimal instead (ie 1010101010.80) was found to be slower then using integers but faster than strings.
2. Added a `depth` column - this is `number_indents + 2` for all Headings and their descendents.
    1. Chapters are the exception to this, they have a position of `number_indents + 1`, ie `1`.
    2. This makes the field an absolute definition of the depth, unlike the `number_indents` field which is 0 for both Chapters and Headings despite them being at different conceptual depths in the hierarchy
    3. At present `depth == 0` is a single conceptual root of the hierarchy encompassing all Chapters and all of their descendants
3. Populated `validity_end_date` in `tree_nodes` - this is never populated in the indents table
    1. the missing end date means that we need to join the indents table on to itself to fetch only the most recent indent
    2. this JOIN is instead done during the generation of the `tree_nodes` view to both simplify querying the `tree_nodes` data and to avoid repeatedly doing the JOIN during hierarchy lookups

**Note:** The `position` identifier is not unique because there may be multiple `tree_nodes` records for a goods nomenclature, all with the same `position` but different validity dates. A unique identifier would be either the triple of the identifier and dates, ie `position + validity_start_date + validity_end_date` or the `goods_nomenclature_indent_sid` which refers to a `tree_nodes` record for a given point in time.

### Indexing

The primary index used for hierarchy lookups is `depth` + `position`.

* Using `depth` as the first index key allows for efficient segmenting of the dataset and aligns with most lookups trying to min/max records at a specific depth. * `position` is the second index key to allow finding the min/max after the subset of records at the expected depth is selected

`validity_start_date` and `validity_end_date` are not in the index because once the Postgres has filtered by `depth` and `position`, there are not many records to walk through so there is not much performance benefit. There would be a memory cost though, because every entry in the index would also require 2 dates that will be much larger then the `int` + `bigint` for `depth` + `position`

There are also 2 other indexes
* `goods_nomenclature_sid` - this allows for efficient JOINs to the goods_nomenclatures table
* `oid` (unique) - this is the `oid` from the indents table. Refreshing a materialized view concurrently (ie without blocking reads from the view) requires the materialized view to have a unique index.

## Querying in SQL

**Note:** `origin` record references the `tree_nodes` record you are fetching relatives for, eg ancestors of `origin`, or children of `origin`

### Ancestors

These can be queried by fetching the maximium `position` at every `depth`, where -;
* `depth` is less than the `depth` of the origin `tree_node` record
* and the `position` is less than the `position` of the origin record

### Next sibling

The `tree_nodes` record with
* same `depth` as the origin record
* the lowest `position` that is still greater than the origin records `position`

### Previous sibling

_Note: Due to how we read the tree this is less useful then next sibling_

The `tree_nodes` record with
* same `depth` as the origin record
* and has the highest `position` that is still less than the origin records `position`

### Children

This is every `tree_nodes` record where -;
* the child nodes `depth` is exactly 1 greater than the `depth` of the origin record
* and the child nodes `position` is greater than the `position` of the origin `tree_nodes` record
* and the child nodes `position` is less than the `position` of next sibling of the origin record

### Descendents

This is every `tree_nodes` record where -;
* the child nodes `depth` is greater than the `depth` of the origin record
* and the child nodes `position` is greater than the `position` of the origin `tree_nodes` record
* and the child nodes `position` is less than the `position` of next sibling of the origin record

### Goods Nomenclatures

The above describes how `tree_nodes` can be related to each other. To find relatives on `goods_nomenclatures` records you can JOIN to `tree_nodes` via `goods_nomenclature_sid`, JOIN the `tree_nodes` to themselves via `position` and `depth`, then in turn back onto `goods_nomenclatures` via the relatives `goods_nomenclature_sid`.

```
+----+    +----------+    +-----------+    +---------+
| GN | -> |  Origin  | -> | Related   | -> | Related |
+----+    | TreeNode |    | TreeNodes |    |   GNs   |
          +----------+    +-----------+    +---------+
```

## Querying in Ruby

There are abstractions for all for the above encapsulated in the Sequel relationships on the `GoodsNomenclatures` model

_Note: These are all eager loadable_

### Tree relationships

* `ns_parent` - returns the parent
* `ns_ancestors` - returns a list of ancestors - starting at root of tree
* `ns_children` - all immediate children
* `ns_descendants` - all descendants of a goods nomenclature, at any depth

### Populators

GoodsNomenclature records loaded for one relationship are often relevant to others, so where possible the fetching a relationship will also populate related relationships on the data model. Eg, fetching `#ns_ancestors` will also populate the `#ns_parent` relationship since that is the closest of the ancestors.

* `ns_ancestors` also populates `ns_parent` on self and all ancestors
* `ns_descendants` also populates
    * `ns_parent` for all descendants
    * `ns_children` for self plus all descendants
    * `ns_ancestors` for all descendants _if_ self already has ancestors loaded

The above means you can get a nice recursive tree of children, so in the following example the first line will generate 2 queries and the second line will generate 0 queries.

```
chapter = Chapter.actual.by_code('01').eager(:ns_descendants).take
chapter.ns_children.first.ns_children.first.ns_children.first.ns_parent.ns_children.second
```

And if you eager load `#ns_ancestors` before `#ns_descendants` then that too will be populated, so the following example triggers 3 queries for line 1, and 0 for line 2 or any subsequent movement around the eager loaded hierarchy.

```
chapter = Chapter.actual.by_code('01').eager(ns_ancestors, :ns_descendants).take
chapter.ns_children.first.ns_children.first.ns_children.map(&ns_ancestors)
```

### Useful methods

* `#ns_leaf?` - tells you whether a Goods Nomenclature is branch or leaf (ie, no children). This benefits from eager loading (ns_children) and the Populators (see above)
* `#ns_declarable?` - replacement for `#declarable` but eager loadable, internally relies upon `#ns_leaf?`
* `#number_indents` - if data is loaded via the nested set relationships then this is populated automatically without needing to eager load `goods_nomenclature_indents`
* `#depth` - internal reference for the depth of a goods nomenclature, normally `number_indents` + 2 except for chapters which are `number_indents` + 1
* `#goods_nomenclature_class` - this now utilises ns_leaf? internally so benefits from eager loading `#ns_children` or `#ns_descendants` the same
* `.ns_declarable` - Dataset method to filter by only declarable goods nomenclatures - this does do a left join to check for child_nodes _but_ it skips any rows which have children so shouldn't impact results

### Measures

There are two new eager loadable measures relationships

* `ns_measures` - all measures directly on a goods nomenclature
* `ns_overview_measures` - the overview measures directly on a goods nomenclature

These are different from the existing `#measures` and `#overview_measures` because they only load measures directly referencing the goods nomenclature.

`#measures` and `#overview_measures` would also include the measures against the goods nomenclatures ancestors. This was changed because it allows for eager loading and avoids repeat loads of the same measures for all descendants of the goods nomenclature they apply to.

There are two model methods which replicate the old behaviour -;

* `#applicable_measures` - concatenation of measures against both self and ancestors
* `#applicable_overview_measures` - concatenation of overview measures against both self and ancestors

#### Eager loading measures

The measures will need eager loading for both self and ancestors, eg

```
Chapter.actual
       .by_code('01')
       .eager(:ns_measures, ns_ancestors: :ns_measures)
       .take
```

This makes it possible to eager load measures for all descendants as well -;

```
Chapter.actual
       .by_code('01')
       .eager(:ns_measures,
              ns_ancestors: :ns_measures,
              ns_descendants: :ns_measures)
       .take
```

If you need to eager load relationships below measures, you'll need to duplicate parts of the eager load block with variables/constants, eg

```
MEASURE_EAGER = {
	ns_measures: [:measure_type,
                 { measure_conditions: :measure_condition_code }]
}
Chapter.actual
       .by_code('01')
       .eager(MEASURE_EAGER,
              ns_ancestors: MEASURE_EAGER,
              ns_descendants: MEASURE_EAGER)
       .take
```

### Virtual leaf column

This not the easiest method to consume but solves a specific scenario, and is relatively quick - ~0.5 seconds for all goods nomenclatures. If you need to find the 'leaf' status of a goods nomenclature at the SQL level, eg you want to fetch all non declarable commodities without needing to load every commodity back to Ruby.

```
GoodsNomenclature.with_leaf_column
                 .where(leaf: false)
                 .exclude(producline_suffix: '80')
                 .all
```

Because this uses a join and group you may need `Sequel.dataset.from_self` to nest the query depending upon what your using it for.

### Some examples

* `HeadingsService::PrecacheService.rb`
* `HeadingsService::Serialization::NsNondeclarableService`
* `Api::V2::ChaptersController`
