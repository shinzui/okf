--| Current schema fixture for bundle-local handles and explicit external URIs.
let Profile = ../../../dhall/Profile.dhall

let TypeRule = ../../../dhall/defaults/TypeRule.dhall

let FieldRule = ../../../dhall/defaults/FieldRule.dhall

let HandleReferenceRule = ../../../dhall/defaults/HandleReferenceRule.dhall

let Cardinality = ../../../dhall/Cardinality.dhall

let field = ../../../dhall/mk/FieldRule.dhall

let references =
      (field.localOrExternalReference "references" "ADR" [ "mori" ])
        with cardinality = Cardinality.List

let selfReference =
      FieldRule::{
      , field = "selfReference"
      , cardinality = Cardinality.Scalar
      , reference =
          Some HandleReferenceRule::{ localPrefix = "ADR", allowSelf = True }
      }

in    { name = "document-references"
      , description = Some
          "Architecture decisions with bundle-local or explicitly external references."
      , okfVersion = "0.1"
      , frontmatter =
        { required = [ field.plain "type", field.plain "title" ]
        , recommended = [ references, selfReference ]
        , optional = [] : List FieldRule.Type
        }
      , allowUnknownTypes = False
      , allowUnknownFields = True
      , idField = Some "docId"
      , types =
        [ TypeRule::{
          , type = "Decision Record"
          , pathPattern = Some "decisions/*"
          , idPrefix = Some "ADR"
          }
        ]
      }
    : Profile
