--| Constructors for one field inside a list element record.
let NestedFieldRule = ../defaults/NestedFieldRule.dhall

let Cardinality = ../Cardinality.dhall

let FieldFormat = ../FieldFormat.dhall

let FieldCondition = ../FieldCondition.dhall

let PathReferenceRule = ../defaults/PathReferenceRule.dhall

in  { plain = \(field : Text) -> NestedFieldRule::{ field }
    , documented =
        \(field : Text) ->
        \(description : Text) ->
          NestedFieldRule::{ field, description = Some description }
    , enum =
        \(field : Text) ->
        \(allowedValues : List Text) ->
          NestedFieldRule::{ field, allowedValues }
    , scalar =
        \(field : Text) -> NestedFieldRule::{ field, cardinality = Cardinality.Scalar }
    , list =
        \(field : Text) -> NestedFieldRule::{ field, cardinality = Cardinality.List }
    , rfc3339Utc =
        \(field : Text) -> NestedFieldRule::{ field, format = Some FieldFormat.Rfc3339Utc }
    , date =
        \(field : Text) -> NestedFieldRule::{ field, format = Some FieldFormat.Date }
    , uri =
        \(field : Text) -> NestedFieldRule::{ field, format = Some FieldFormat.Uri }
    , uriWithScheme =
        \(field : Text) ->
        \(scheme : Text) ->
          NestedFieldRule::{ field, format = Some (FieldFormat.UriWithScheme scheme) }
    , documentHandle =
        \(field : Text) ->
        \(prefix : Text) ->
          NestedFieldRule::{ field, format = Some (FieldFormat.DocumentHandle prefix) }
    , actor =
        \(field : Text) -> NestedFieldRule::{ field, format = Some FieldFormat.Actor }
    , humanActor =
        \(field : Text) ->
          NestedFieldRule::{ field, format = Some FieldFormat.HumanActor }
    , integer =
        \(field : Text) -> NestedFieldRule::{ field, format = Some FieldFormat.Integer }
    , nonNegativeInteger =
        \(field : Text) ->
          NestedFieldRule::{ field, format = Some FieldFormat.NonNegativeInteger }
    , boolean =
        \(field : Text) ->
          NestedFieldRule::{ field, format = Some FieldFormat.Boolean }
    , conditional =
        \(rule : NestedFieldRule.Type) ->
        \(condition : FieldCondition) ->
          rule with when = Some condition
    , bundlePath =
        \(field : Text) ->
          NestedFieldRule::{ field, path = Some PathReferenceRule::{=} }
    , localOrExternalPath =
        \(field : Text) ->
        \(externalUriSchemes : List Text) ->
          NestedFieldRule::{
          , field
          , path = Some PathReferenceRule::{ externalUriSchemes }
          }
    }
