# The deterministic check named by computations/order-total.md's `attester`.
#
# Deterministic and with no language model in it, per the specification: it takes
# a receipt and returns a verdict. okf never runs it, never sees a receipt, and
# never computes a verdict; this file is here because a bundle records where the
# check lives, and because a path-valued frontmatter field naming a file that is
# not Markdown should still resolve.

EXPECTED_SQL = """
SELECT SUM(quantity * unit_amount_minor) AS total_minor
FROM order_lines
WHERE order_id = :order_id
"""


def attest(receipt, parameters):
    """Whether this receipt shows the sanctioned computation actually ran."""
    return (
        _normalize(receipt["executed_sql"]) == _normalize(EXPECTED_SQL)
        and set(parameters) == {"order_id"}
    )


def _normalize(sql):
    return " ".join(sql.split())
