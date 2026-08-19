--| Record-completion defaults for a document-reference policy.
let HandleReferenceRule = ../HandleReferenceRule.dhall

in  { Type = HandleReferenceRule
    , default =
      { externalUriSchemes = [] : List Text
      , allowSelf = False
      , allowLocal = True
      , externalUriPattern = None Text
      }
    }
