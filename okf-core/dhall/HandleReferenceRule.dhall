--| Policy for a top-level field containing local document handles or explicit
-- external URI alternatives. okf resolves only the local handle and never
-- performs network or registry lookups for an external URI.
{ localPrefix : Text
, externalUriSchemes : List Text
, allowSelf : Bool
}
