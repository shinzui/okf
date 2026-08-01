--| Named value formats available to profile field rules.
--
-- The first five constrain text. `Actor` and `HumanActor` constrain text against
-- the OKF v0.2 actor convention (specification §7): `<producer>/<version>`,
-- `human:<id>`, or `process:<id>`, with `HumanActor` accepting only the second.
-- `Integer`, `NonNegativeInteger`, and `Boolean` constrain a value that is not
-- text at all, and declaring one of them refines an unspecified cardinality to
-- `Scalar`.
< Rfc3339Utc
| Date
| Uri
| UriWithScheme : Text
| DocumentHandle : Text
| Actor
| HumanActor
| Integer
| NonNegativeInteger
| Boolean
>
