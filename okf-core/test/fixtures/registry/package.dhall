--| Fixture registry for Okf.Profile.Registry tests. Deliberately mixes profile
-- values, a nested namespace, a schema record, and a non-profile field, so the
-- enumeration walk is exercised on every shape it must handle.
{ Profile = ../../../dhall/defaults/Profile.dhall
, postgresql = ../profiles/postgresql.dhall
, nested = { decisions = ../profiles/decisions.dhall }
, note = "not a profile"
}
