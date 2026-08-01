--| Record-completion defaults for a path-valued field policy.
--
-- The defaults are the strictest coherent policy: no absolute URL is permitted,
-- so the value must be a path, and a path resolving to the concept carrying it
-- is reported. An author widens from there.
let PathReferenceRule = ../PathReferenceRule.dhall

in  { Type = PathReferenceRule
    , default =
      { externalUriSchemes = [] : List Text
      , allowSelf = False
      }
    }
