module AccountCatalogs
  class Personal < Base
    CHART_OF_ACCOUNTS = [
      {
        category: "ASSET",
        account_types: [
          {
            account_type: "Cash & Liquid Assets",
            detail_types: [ "Checking Account", "Savings Account", "Physical Cash & Digital Wallets", "Suspense / Clearing" ],
            description: "Cash and funds that are readily available for spending or short-term needs."
          },

          {
            account_type: "Investments & Long-Term Assets",
            detail_types: [ "Retirement Accounts", "Taxable Brokerage", "Real Estate & Property", "Health Savings", "Loans & Receivables", "Personal Property & Equipment" ],
            description: "Investments and valuable assets held for long-term financial growth or use."
          }
        ]
      },

      {
        category: "LIABILITY",
        account_types: [
          {
            account_type: "Short-Term Debt",
            detail_types: [ "Credit Cards", "Short-Term Loans" ],
            description: "Personal debts and obligations that are expected to be paid in the near term."
          },

          {
            account_type: "Long-Term Debt",
            detail_types: [ "Mortgage", "Auto & Student Loans" ],
            description: "Personal debts and loans that are generally repaid over an extended period."
          }
        ]
      },

      {
        category: "EQUITY",
        account_types: [
          {
            account_type: "Personal Net Worth",
            detail_types: [ "Opening Balance", "Retained Savings" ],
            description: "The accumulated value of personal assets after accounting for personal liabilities."
          }
        ]
      },

      {
        category: "INCOME",
        account_types: [
          {
            account_type: "Personal Inflows",
            detail_types: [ "Earned Salary & Wages", "Side Hustle / Freelance", "Investment Returns", "Gifts & Reimbursements", "Other Personal Income" ],
            description: "Money received from employment, personal activities, investments, or other sources."
          }
        ]
      },

      {
        category: "EXPENSE",
        account_types: [
          {
            account_type: "Personal Outflows",
            detail_types: [ "Housing & Utilities", "Living & Daily Needs", "Transportation", "Lifestyle & Subscriptions", "Healthcare & Insurance", "Financial Expenses", "Other Personal Expense" ],
            description: "Money spent on living costs, financial obligations, and personal activities."
          }
        ]
      }
    ].freeze

    CORE = {
      cash: {
        name: "Cash",
        base: "asset",
        type: "Cash & Liquid Assets",
        detail: "Physical Cash & Digital Wallets"
      },
      opening_balance: {
        name: "Opening Balance Equity",
        base: "equity",
        type: "Personal Net Worth",
        detail: "Opening Balance"
      },
      suspense: {
        name: "Suspense / Clearing",
        base: "asset",
        type: "Cash & Liquid Assets",
        detail: "Suspense / Clearing"
      },
      uncategorized_income: {
        name: "Uncategorized Income",
        base: "income",
        type: "Personal Inflows",
        detail: "Other Personal Income"
      },
      uncategorized_expense: {
        name: "Uncategorized Expense",
        base: "expense",
        type: "Personal Outflows",
        detail: "Other Personal Expense"
      }
    }.freeze

    STARTER_ACCOUNTS = {
      checking: {
        name: "Bank Account",
        base: "asset",
        type: "Cash & Liquid Assets",
        detail: "Checking Account"
      },
      savings: {
        name: "Savings",
        base: "asset",
        type: "Cash & Liquid Assets",
        detail: "Savings Account"
      },
      wallet: {
        name: "Digital Wallet",
        base: "asset",
        type: "Cash & Liquid Assets",
        detail: "Physical Cash & Digital Wallets"
      },
      credit_card: {
        name: "Credit Card",
        base: "liability",
        type: "Short-Term Debt",
        detail: "Credit Cards"
      }
    }.freeze

    RECOMMENDED = {
      salary_wages: {
        name: "Salary & Wages",
        base: "income",
        type: "Personal Inflows",
        detail: "Earned Salary & Wages",
        parent: :uncategorized_income
      },
      groceries_food: {
        name: "Groceries & Food",
        base: "expense",
        type: "Personal Outflows",
        detail: "Living & Daily Needs",
        parent: :uncategorized_expense
      },
      rent_housing: {
        name: "Rent & Housing",
        base: "expense",
        type: "Personal Outflows",
        detail: "Housing & Utilities",
        parent: :uncategorized_expense
      },
      transport: {
        name: "Transportation",
        base: "expense",
        type: "Personal Outflows",
        detail: "Transportation",
        parent: :uncategorized_expense
      }
    }.freeze
  end
end
