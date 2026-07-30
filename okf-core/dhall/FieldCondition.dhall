--| A same-scope predicate controlling whether a field presence rule applies.
--
-- `field` names a sibling in the same top-level or nested object. `hasValue`
-- lists the closed scalar textual values that activate the presence rule.
{ field : Text, hasValue : List Text }
