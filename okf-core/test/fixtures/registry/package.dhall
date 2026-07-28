--| Fixture registry for Okf.Profile.Registry tests. Deliberately mixes profile
-- values, a nested namespace, a schema record, a non-profile field, and one
-- frozen okf 0.2.x descriptor, so the enumeration walk is exercised on every
-- shape it must handle — including a registry mixing old and new profiles.
{ Profile = ../../../dhall/defaults/Profile.dhall
, postgresql = ../profiles/postgresql.dhall
, legacy = ../profiles/legacy-0.2.dhall
, nested = { decisions = ../profiles/decisions.dhall }
, note = "not a profile"
}
