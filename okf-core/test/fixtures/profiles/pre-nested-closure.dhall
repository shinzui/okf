--| FROZEN: complete descriptor at cfecb72e543c28f5a77ff852445fdd0f256b8810.
-- Every reachable record and union is inline; no live schema imports.
let Cardinality = < Any | Scalar | List >

let FieldFormat =
      < Rfc3339Utc
      | Date
      | Uri
      | UriWithScheme : Text
      | DocumentHandle : Text
      | Actor
      | HumanActor
      | Integer
      | NonNegativeInteger
      | FiniteDecimal
      | Boolean
      >

let FieldCondition = { field : Text, hasValue : List Text }

let HandleReferenceRule =
      { localPrefix : Text
      , externalUriSchemes : List Text
      , allowSelf : Bool
      , allowLocal : Bool
      , externalUriPattern : Optional Text
      }

let PathReferenceRule = { externalUriSchemes : List Text, allowSelf : Bool }

let NestedFieldRule =
      { field : Text
      , description : Optional Text
      , allowedValues : List Text
      , cardinality : Cardinality
      , format : Optional FieldFormat
      , path : Optional PathReferenceRule
      , when : Optional FieldCondition
      , reference : Optional HandleReferenceRule
      }

let ValueSelector = { field : Text, member : Optional Text }

let PresenceConstraint =
      { when : Optional FieldCondition
      , whenAnyPresent : List ValueSelector
      , requireAll : List ValueSelector
      , requireAny : List ValueSelector
      }

let TimestampOrderConstraint = { before : Text, after : Text }

let MembershipConstraint = { source : ValueSelector, target : ValueSelector }

let UniqueValuesConstraint = { selectors : List ValueSelector }

let NestedRules =
      { required : List NestedFieldRule
      , recommended : List NestedFieldRule
      , optional : List NestedFieldRule
      , presenceConstraints : List PresenceConstraint
      , timestampOrderConstraints : List TimestampOrderConstraint
      }

let FieldRule =
      { field : Text
      , description : Optional Text
      , allowedValues : List Text
      , cardinality : Cardinality
      , format : Optional FieldFormat
      , elementFields : Optional NestedRules
      , objectFields : Optional NestedRules
      , reference : Optional HandleReferenceRule
      , path : Optional PathReferenceRule
      , when : Optional FieldCondition
      , uniqueBy : Optional Text
      }

let FrontmatterRules =
      { required : List FieldRule
      , recommended : List FieldRule
      , optional : List FieldRule
      , presenceConstraints : List PresenceConstraint
      , timestampOrderConstraints : List TimestampOrderConstraint
      , membershipConstraints : List MembershipConstraint
      , uniqueValuesConstraints : List UniqueValuesConstraint
      }

let plain =
      \(field : Text) ->
        { field
        , description = None Text
        , allowedValues = [] : List Text
        , cardinality = Cardinality.Any
        , format = None FieldFormat
        , elementFields = None NestedRules
        , objectFields = None NestedRules
        , reference = None HandleReferenceRule
        , path = None PathReferenceRule
        , when = None FieldCondition
        , uniqueBy = None Text
        }

let nestedPlain =
      \(field : Text) ->
        { field
        , description = None Text
        , allowedValues = [] : List Text
        , cardinality = Cardinality.Any
        , format = None FieldFormat
        , path = None PathReferenceRule
        , when = None FieldCondition
        , reference = None HandleReferenceRule
        }

let select = \(field : Text) -> { field, member = None Text }

let scalar = \(field : Text) -> nestedPlain field // { cardinality = Cardinality.Scalar }

let members : NestedRules =
      { required = [ scalar "name" ]
      , recommended = [] : List NestedFieldRule
      , optional =
        [ scalar "start" // { format = Some FieldFormat.Rfc3339Utc }
        , scalar "end" // { format = Some FieldFormat.Rfc3339Utc }
        , scalar "score" // { format = Some FieldFormat.FiniteDecimal }
        ]
      , presenceConstraints =
        [ { when = None FieldCondition
          , whenAnyPresent = [ select "start" ]
          , requireAll = [ select "end" ]
          , requireAny = [] : List ValueSelector
          }
        ]
      , timestampOrderConstraints = [ { before = "start", after = "end" } ]
      }

let fields : FrontmatterRules =
      { required = [] : List FieldRule
      , recommended = [] : List FieldRule
      , optional =
        [ plain "rows" // { elementFields = Some members }
        , plain "settings" // { objectFields = Some members }
        , plain "names" // { cardinality = Cardinality.List }
        , plain "start" // { cardinality = Cardinality.Scalar, format = Some FieldFormat.Rfc3339Utc }
        , plain "end" // { cardinality = Cardinality.Scalar, format = Some FieldFormat.Rfc3339Utc }
        ]
      , presenceConstraints =
        [ { when = None FieldCondition
          , whenAnyPresent = [ select "start" ]
          , requireAll = [ select "end" ]
          , requireAny = [] : List ValueSelector
          }
        ]
      , timestampOrderConstraints = [ { before = "start", after = "end" } ]
      , membershipConstraints =
        [ { source = { field = "rows", member = Some "name" }, target = select "names" } ]
      , uniqueValuesConstraints = [ { selectors = [ select "names", { field = "settings", member = Some "name" } ] } ]
      }

in  { name = "pre-nested-closure"
    , description = Some "The complete descriptor immediately before nested closure."
    , okfVersion = "0.2"
    , guidance = Some "Frozen guidance"
    , frontmatter = fields
    , allowUnknownTypes = False
    , allowUnknownFields = False
    , idField = None Text
    , requireBundleVersion = Some "0.2"
    , types =
      [ { type = "Note"
        , description = None Text
        , guidance = Some "Frozen type guidance"
        , frontmatter = fields
        , pathPattern = None Text
        , resourceScheme = None Text
        , requireSchemaSection = False
        , schemaColumns = [] : List Text
        , idPrefix = None Text
        }
      ]
    }
