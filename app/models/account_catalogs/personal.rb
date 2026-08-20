module AccountCatalogs
  class Personal < Base
    CHART_OF_ACCOUNTS = [
      {
        category: "ASSET",
        account_types: [
          {
            account_type: "Cash & Liquid Assets",
            detail_types: [ "Checking Account", "Savings Account", "Physical Cash & Digital Wallets" ],
            description: "Cash and funds that are readily available for spending or short-term needs."
          },

          {
            account_type: "Investments & Long-Term Assets",
            detail_types: [ "Retirement Accounts", "Taxable Brokerage", "Real Estate & Property", "Health Savings" ],
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
            detail_types: [ "Earned Salary & Wages", "Side Hustle / Freelance", "Investment Returns", "Gifts & Reimbursements" ],
            description: "Money received from employment, personal activities, investments, or other sources."
          }
        ]
      },

      {
        category: "EXPENSE",
        account_types: [
          {
            account_type: "Personal Outflows",
            detail_types: [ "Housing & Utilities", "Living & Daily Needs", "Transportation", "Lifestyle & Subscriptions", "Healthcare & Insurance", "Financial Expenses" ],
            description: "Money spent on living costs, financial obligations, and personal activities."
          }
        ]
      }
    ].freeze
  end
end
