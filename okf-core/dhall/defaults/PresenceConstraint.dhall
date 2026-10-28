{ Type = ../PresenceConstraint.dhall
, default =
  { when = None ../FieldCondition.dhall
  , whenAnyPresent = [] : List ../ValueSelector.dhall
  , requireAll = [] : List ../ValueSelector.dhall
  , requireAny = [] : List ../ValueSelector.dhall
  }
}
