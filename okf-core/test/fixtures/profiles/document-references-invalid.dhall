--| Semantically invalid reference policies; Dhall accepts the shape and
-- compileProfile rejects the policy errors before bundle traversal.
let Profile = ../../../dhall/Profile.dhall

let TypeRule = ../../../dhall/defaults/TypeRule.dhall

let FieldRule = ../../../dhall/defaults/FieldRule.dhall

let HandleReferenceRule = ../../../dhall/defaults/HandleReferenceRule.dhall

let FieldFormat = ../../../dhall/FieldFormat.dhall

let policy =
      \(localPrefix : Text) ->
      \(externalUriSchemes : List Text) ->
        Some HandleReferenceRule::{ localPrefix, externalUriSchemes }

let rule =
      \(field : Text) ->
      \(localPrefix : Text) ->
      \(externalUriSchemes : List Text) ->
        FieldRule::{ field, reference = policy localPrefix externalUriSchemes }

in    { name = "invalid-document-references"
      , description = None Text
      , okfVersion = "0.1"
      , frontmatter =
        { required =
          [ rule "badPrefix" "1ADR" ([] : List Text)
          , rule "undeclared" "PAT" ([] : List Text)
          , rule "badScheme" "ADR" [ "mori_" ]
          , FieldRule::{
            , field = "formatted"
            , format = Some (FieldFormat.DocumentHandle "ADR")
            , reference = policy "ADR" ([] : List Text)
            }
          , rule "conflict" "ADR" ([] : List Text)
          ]
        , recommended = [] : List FieldRule.Type
        , optional = [] : List FieldRule.Type
        }
      , allowUnknownTypes = True
      , allowUnknownFields = True
      , idField = Some "docId"
      , types =
        [ TypeRule::{
          , type = "Decision Record"
          , frontmatter =
            { required = [ rule "conflict" "RFC" ([] : List Text) ]
            , recommended = [] : List FieldRule.Type
            , optional = [] : List FieldRule.Type
            }
          , idPrefix = Some "ADR"
          }
        , TypeRule::{ type = "RFC", idPrefix = Some "RFC" }
        , TypeRule::{ type = "Invalid Prefix", idPrefix = Some "1ADR" }
        ]
      }
    : Profile
