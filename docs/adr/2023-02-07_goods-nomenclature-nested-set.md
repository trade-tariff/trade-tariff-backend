# Goods Nomenclature Nested Set

Date: 7 February 2023
Status: Accepted
Present: Matt Lavis, William Fish, Jeremy Wilkins, Ata Dahri

## Context

We currently access the Goods Nomenclature hierarchy in an inefficient manner. We load all relevant descents of the containing Heading from the database, then filter for what is relevant.

We cannot eager load measures, because they need to do their own (non-eager loadable) queries to determine ancestors before they can know which measures to look for.

This leads to a complicated codebase that is hard to optimise because multiple work arounds are required to offset the N+1s caused by our current access to the hierarchy.

## Decision

Move to accessing the Goods Nomenclatures hierarchy via a modified nested set pattern as described in the [design doc](../goods-nomenclature-nested-set.md)

## Consequences

* We speed up access to commodities and subheadings pages
* We can remove the slow overnight generation of the Headings cache in Elastic Search - replacing with direct querying of the database.
* Our interpretation of the hierarchy when presented with invalid data via CDS or Taric may change, eg if indent levels are incorrect.
* We have the tools to optimise other parts of the codebase such as Additional Code search

