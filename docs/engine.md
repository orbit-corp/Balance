
# Introduction

| Relationship          | Valid? | Posting                                            |
| --------------------- | ------ | -------------------------------------------------- |
| ASSET → ASSET         | ✅     | DR destination, CR source                          |
| ASSET → LIABILITY     | ✅     | DR Asset, CR Liability                             |
| LIABILITY → ASSET     | ✅     | DR Liability, CR Asset                             |
| ASSET → EQUITY        | ✅     | DR Asset, CR Equity                                |
| EQUITY → ASSET        | ✅     | DR Equity, CR Asset                                |
| ASSET → INCOME        | ✅     | DR Asset, CR Income                                |
| EXPENSE → ASSET       | ✅     | DR Expense, CR Asset                               |
| EXPENSE → LIABILITY   | ✅     | DR Expense, CR Liability                           |
| LIABILITY → LIABILITY | ✅\*   | DR liability decreasing, CR liability increasing   |
| EQUITY → LIABILITY    | ⚠️     | Event-specific                                     |
| LIABILITY → EQUITY    | ⚠️     | Event-specific                                     |
| INCOME → ASSET        | ❌     | Wrong direction; should be Asset → Income          |
| ASSET → EXPENSE       | ❌     | Wrong direction; should be Expense → Asset         |
| INCOME → EXPENSE      | ❌     | Not a direct primitive                             |
| EXPENSE → INCOME      | ❌     | Not a direct primitive                             |
| INCOME → LIABILITY    | ❌     | Usually requires an intermediate economic event    |
| LIABILITY → INCOME    | ❌     | Usually event-specific                             |
| INCOME → EQUITY       | ❌     | Normally handled through closing/retained earnings |
| EQUITY → INCOME       | ❌     | Not a direct posting                               |
| EXPENSE → EQUITY      | ⚠️     | Usually indirect                                   |
| EQUITY → EXPENSE      | ⚠️     | Usually indirect                                   |
