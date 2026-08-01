# Specification section 10.2's own example of an attester resource: deterministic
# code, no language model, that takes a receipt and returns a verdict. okf never
# runs this file. It exists so the fixture proves a non-Markdown target of a
# path-valued contract field resolves against the bundle inventory.


def attest(receipt):
    """Return whether a run produced its value the sanctioned way."""
    return receipt["executed_sql"].strip() == EXPECTED_SQL.strip()


EXPECTED_SQL = """
SELECT SUM(amount) AS revenue
FROM finance.recognized_revenue
WHERE fiscal_year = @year
"""
