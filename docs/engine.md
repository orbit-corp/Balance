
# Introduction

| Event                 | Account Structure         | Debit           | Credit              | Status            |
| --------------------- | ------------------------- | --------------- | ------------------- | ----------------- |
| Asset Transfer        | ASSET → ASSET             | Destination     | Source              | ✅ Universal       |
| Income Receipt        | ASSET → INCOME            | Asset           | Income              | ✅ Universal       |
| Expense Payment       | EXPENSE → ASSET           | Expense         | Asset               | ✅ Universal       |
| Expense Accrual       | EXPENSE → LIABILITY       | Expense         | Liability           | ✅ Universal       |
| Liability Creation    | ASSET → LIABILITY         | Asset           | Liability           | ✅ Universal       |
| Liability Payment     | LIABILITY → ASSET         | Liability       | Asset               | ✅ Universal       |
| Equity Contribution   | ASSET → EQUITY            | Asset           | Equity              | ✅ Universal       |
| Equity Withdrawal     | EQUITY → ASSET            | Equity          | Asset               | ✅ Universal       |
| Debt Refinance        | LIABILITY → LIABILITY     | Old Liability   | New Liability       | ⚠️ Event Required |
| Asset Acquisition     | ASSET → ASSET / LIABILITY | New Asset       | Funding Source      | ⚠️ Event Required |
| Asset Disposal        | ASSET → ASSET / INCOME    | Funding / Asset | Asset / Income      | ⚠️ Event Required |
| Receivable Creation   | ASSET → INCOME            | Receivable      | Income              | ⚠️ Event Required |
| Receivable Collection | ASSET → ASSET             | Cash            | Receivable          | ✅ Universal       |
| Investment Purchase   | ASSET → ASSET             | Investment      | Cash                | ✅ Universal       |
| Investment Sale       | ASSET → ASSET / INCOME    | Cash            | Investment / Income | ⚠️ Event Required |
