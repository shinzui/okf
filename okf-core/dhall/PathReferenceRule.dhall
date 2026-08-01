--| Policy for a field whose value names a path or URI per OKF v0.2
-- specification §6.2: an absolute URL, a bundle-relative path beginning with
-- `/`, or an ordinary relative path. A relative path resolves against the
-- directory of the concept carrying it, exactly as a Markdown link in that
-- concept's body would.
--
-- Deliberately distinct from `HandleReferenceRule`, which resolves a `PREFIX-N`
-- document handle against the bundle's document-ID index. A path resolves
-- against the bundle's concept tree instead, and declaring both policies on one
-- key is a profile definition error: a value cannot be read as both.
--
-- `externalUriSchemes` lists the URL schemes the profile permits; an empty list
-- means no absolute URL is permitted and the value must be a path. okf resolves
-- only paths, and only to concepts: a path naming a `.md` file must name one
-- that exists in the bundle, and a path naming any other file is accepted
-- without a check, because profile validation never touches the filesystem.
-- `allowSelf` permits a path that resolves to the concept carrying it.
{ externalUriSchemes : List Text
, allowSelf : Bool
}
