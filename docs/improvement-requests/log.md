# Bundle Update Log

## 2026-07-30

* **Addition**: IR-7: distinguish optional profile fields from authoring recommendations.

## 2026-07-29

* **Acceptance**: IR-1 through IR-6 after critical design review, with corrected scope and semantics recorded in each request.
* **Planning**: Split implementation into the type-aware/value-safe profile MasterPlan and the dependent structured-metadata/document-relationships MasterPlan.
* **Traceability**: Link every accepted request to its primary target ExecPlan and related coordinating plans in frontmatter and review prose.
* **Deferral**: Leave arbitrary regular-expression field patterns unapproved until a concrete catalog consumer exists.

## 2026-07-28

* **Addition**: IR-6: check that document handles referenced in frontmatter resolve to real concepts.
* **Addition**: IR-5: express field requirements that depend on another field's value.
* **Addition**: IR-4: declare field cardinality and the shape of nested frontmatter records.
* **Addition**: IR-3: constrain field value formats for the open-ended keys a vocabulary cannot describe.
* **Addition**: IR-2: let a profile close its frontmatter vocabulary.
* **Addition**: IR-1: constrain frontmatter values with closed vocabularies, scoped per concept type.
* **Addition**: Open the improvement-request bundle, governed by the shared `coordination.improvementRequests` profile.
