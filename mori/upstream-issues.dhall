let UpstreamIssues =
      https://raw.githubusercontent.com/shinzui/mori-schema/b85081a0e935a976202fd7a1227f8b93e2cbeb23/extensions/upstream-issues/package.dhall
        sha256:50f8b061a1bd999aac83e3f0ed69cd5a829d2bcf101f556a733f52ed9671e064

in  UpstreamIssues.UpstreamIssuesCatalog::{
    , entries =
      [ UpstreamIssues.UpstreamIssue::{
        , key = "cmark-gfm-hs-drops-footnote-labels"
        , dependency = "cmark-gfm-hs"
        , summary =
            "commonmarkToNode returns the nullary constructors FOOTNOTE_REFERENCE and FOOTNOTE_DEFINITION, discarding the footnote label that the C library stores in node->as.literal, so an AST walk cannot recover which footnote a body cites"
        , status = UpstreamIssues.IssueStatus.Active
        , revisitTrigger = Some
            "When kivikakk/cmark-gfm-hs carries the footnote label on both node constructors (for example FOOTNOTE_DEFINITION Text), or accepts a patch doing so. The C side already supports this: github/cmark-gfm commit c123e68 added CMARK_NODE_FOOTNOTE_DEFINITION to cmark_node_get_literal, and that commit is present in the vendored 0.29.0.gfm.13 sources (cbits/node.c lines 374-381 list both footnote node types), so only the Haskell binding's toNode conversion (CMarkGFM.hsc lines 366-369) needs changing. Two apparent workarounds are closed: the reverse conversion raises error \"constructing footnotes not supported\" for both types (CMarkGFM.hsc lines 520-521), so nodeToCommonmark on a footnote node crashes. Note when patching that cbits/blocks.c lines 487-509 overwrite a MATCHED reference's literal with its ordinal number, so a matched reference yields \"1\" rather than a label; unmatched references and all definitions keep their label, and definitions plus unmatched references cover every label a document uses. okf needs this for OKF v0.2 per-claim attribution, where a footnote label is the join key into a concept's sources[].id (specification section 5.1)."
        , workaroundPath = Some
            "docs/plans/41-join-per-claim-footnote-attribution-to-okf-v0-2-source-entries.md"
        , upstreamUrl = Some "https://github.com/kivikakk/cmark-gfm-hs"
        , tags =
          [ "markdown"
          , "footnotes"
          , "okf-v0.2"
          , "ffi-binding"
          , "no-upstream-ticket"
          ]
        }
      ]
    }
