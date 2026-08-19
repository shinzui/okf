--| Policy for a top-level or nested field containing local document handles or
-- explicit external URI alternatives. `allowLocal` can prohibit the local
-- spelling; `externalUriPattern`, when present, is a whole-value POSIX extended
-- regular expression applied after URI syntax and scheme checks. okf resolves
-- only an allowed local handle and never performs network or registry lookups
-- for an external URI.
{ localPrefix : Text
, externalUriSchemes : List Text
, allowSelf : Bool
, allowLocal : Bool
, externalUriPattern : Optional Text
}
