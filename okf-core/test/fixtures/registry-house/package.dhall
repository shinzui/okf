--| Second registry for multi-source tests. It publishes one export that
-- collides with the main registry and one unique export, using only sibling
-- fixtures so enumeration stays offline.
{ postgresql = ../profiles/postgresql.dhall
, runbooks = ../profiles/decisions.dhall
}
