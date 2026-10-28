# Bundle Update Log

## 2026-10-28

* **Traceability**: IR-9: identify the linked implementation plan by its full title
  to distinguish the two plans numbered 70; retain the existing targetPlan path.

## 2026-10-19

* **Addition**: IR-10: fail `okf validate --profile-enforce` when no profile is
  applied, instead of passing with no profile checks run.
* **Addition**: IR-11: let a profile close the vocabulary of nested frontmatter
  records, the follow-up IR-2 and IR-4 left out of scope.
* **Status reconciliation**: IR-1 through IR-8 changed from accepted to completed
  after checking their implementation plans' progress and outcomes against the
  release changelog. Completion metadata records this audit's confirmation time,
  not an inferred historical implementation time; original review records remain
  unchanged. IR-3 is complete only in its accepted named-format scope.
* **Traceability**: Added the missing IR-8 targetPlan for
  [ExecPlan 64](../plans/64-add-nested-reference-policies-and-record-list-uniqueness.md)
  and visible implementation-plan links in every completed request's Status
  section, including both plans needed for IR-1 and IR-4.
* **Planning**: IR-9 remains accepted and linked to
  [ExecPlan 70](../plans/70-express-single-concept-product-discovery-constraints-in-profile-descriptors.md),
  whose implementation milestones remain unchecked.

## 2026-10-16

* **Acceptance and planning**: IR-9 validated against the descriptor implementation and producer checker; nine missing rules and the existing inline-name uniqueness capability clarified, and ExecPlan 70 linked for implementation.

* **Addition**: IR-9: express the single-concept product-discovery constraints of the okf-profiles jobs, product-research, features, and use-case profiles in profile descriptors, retiring the okf-owned rules of its interim checker.

## 2026-08-19

* **Addition and acceptance**: IR-8: add nested reference policies and
  per-record uniqueness constraints to profiles.

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
