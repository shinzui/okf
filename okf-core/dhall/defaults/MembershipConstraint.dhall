let Selector = ./ValueSelector.dhall

in  { Type = ../MembershipConstraint.dhall
    , default = { source = Selector::{=}, target = Selector::{=} }
    }
