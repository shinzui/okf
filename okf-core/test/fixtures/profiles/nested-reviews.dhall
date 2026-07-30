let Profile = ../../../dhall/Profile.dhall

let FieldRule = ../../../dhall/defaults/FieldRule.dhall

let NestedFieldRule = ../../../dhall/defaults/NestedFieldRule.dhall

let TypeRule = ../../../dhall/defaults/TypeRule.dhall

let Cardinality = ../../../dhall/Cardinality.dhall

let FieldFormat = ../../../dhall/FieldFormat.dhall

let field = ../../../dhall/mk/FieldRule.dhall

in    { name = "nested-reviews"
      , description = Some "Validates one level of structured review records."
      , okfVersion = "0.1"
      , frontmatter =
        { required =
          [ field.plain "type"
          , field.recordList
              "reviews"
              { required =
                [ NestedFieldRule::{
                  , field = "kind"
                  , allowedValues = [ "human", "model" ]
                  }
                , NestedFieldRule::{ field = "reviewer", cardinality = Cardinality.Scalar }
                , NestedFieldRule::{
                  , field = "reviewed_at"
                  , format = Some FieldFormat.Rfc3339Utc
                  }
                , NestedFieldRule::{
                  , field = "document_timestamp"
                  , format = Some FieldFormat.Rfc3339Utc
                  }
                , NestedFieldRule::{
                  , field = "scope"
                  , allowedValues =
                    [ "content"
                    , "technical-accuracy"
                    , "editorial"
                    , "catalog-metadata"
                    , "content-and-metadata"
                    ]
                  }
                , NestedFieldRule::{
                  , field = "outcome"
                  , allowedValues = [ "approved", "changes-requested", "commented" ]
                  }
                , NestedFieldRule::{ field = "context", cardinality = Cardinality.Scalar }
                ]
              , recommended =
                [ NestedFieldRule::{ field = "notes", cardinality = Cardinality.Scalar } ]
              , optional = [] : List NestedFieldRule.Type
              }
          ]
        , recommended = [] : List FieldRule.Type
        , optional = [] : List FieldRule.Type
        }
      , allowUnknownTypes = False
      , allowUnknownFields = True
      , idField = None Text
      , types = [ TypeRule::{ type = "Reviewed Concept" } ]
      }
    : Profile
