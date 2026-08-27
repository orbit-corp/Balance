module AccountCatalogs
  class Business < Base
    CHART_OF_ACCOUNTS = [
      {
        category: "ASSET",
        account_types: [
          {
            account_type: "Bank",
            detail_types: [ "Cash on hand", "Checking", "Money Market", "Rents Held in Trust", "Savings", "Trust Accounts" ],
            description: "Accounts used to hold and manage cash and cash equivalents."
          },

          {
            account_type: "Accounts receivable (A/R)",
            detail_types: [ "Accounts Receivable (A/R)" ],
            description: "Money owed to the business by customers for goods or services provided on credit."
          },

          {
            account_type: "Other Current Assets",
            detail_types: [ "Allowance for Bad Debts", "Development Costs", "Employee Cash Advances", "Inventory", "Investment - Other", "Loans to Officers", "Loans to Others", "Loans to Shareholders", "Other Current Assets", "Prepaid Expenses", "Undeposited Funds" ],
            description: "Short-term assets expected to be converted to cash, used, or realized within the operating cycle."
          },

          {
            account_type: "Fixed Assets",
            detail_types: [ "Accumulated Depletion", "Accumulated Depreciation", "Buildings", "Furniture & Fixtures", "Land", "Leasehold Improvements", "Machinery & Equipment", "Other Fixed Assets", "Vehicles" ],
            description: "Long-term physical assets used by the business in its operations."
          },

          {
            account_type: "Other Assets",
            detail_types: [ "Accumulated Amortization", "Goodwill", "Licenses", "Organizational Costs", "Other Long-term Assets", "Security Deposits" ],
            description: "Long-term assets that do not fall under current or fixed asset categories."
          }
        ]
      },

      {
        category: "LIABILITY",
        account_types: [
          {
            account_type: "Credit Card",
            detail_types: [ "Credit Card" ],
            description: "Amounts owed on business credit cards for purchases and other charges."
          },

          {
            account_type: "Accounts payable (A/P)",
            detail_types: [ "Accounts Payable (A/P)" ],
            description: "Amounts the business owes to suppliers and vendors for purchases made on credit."
          },

          {
            account_type: "Other Current Liabilities",
            detail_types: [ "Federal Income Tax Payable", "Insurance Payable", "Line of Credit", "Loan Payable", "Other Current Liabilities", "Payroll Clearing", "Payroll Tax Payable", "Sales Tax Payable", "State/Local Income Tax Payable" ],
            description: "Short-term obligations expected to be settled within the normal operating cycle."
          },

          {
            account_type: "Long Term Liabilities",
            detail_types: [ "Notes Payable", "Other Long Term Liabilities", "Shareholder Notes Payable" ],
            description: "Financial obligations that are generally due more than one year in the future."
          }
        ]
      },

      {
        category: "EQUITY",
        account_types: [
          {
            account_type: "Equity",
            detail_types: [ "Accumulated Adjustment", "Common Stock", "Estimated Taxes", "Owner's Equity", "Paid-in Capital or Surplus", "Partner Contributions", "Partner Distributions", "Partner's Equity", "Preferred Stock", "Retained Earnings", "Treasury Stock" ],
            description: "The owners' residual interest in the business after liabilities are deducted from assets."
          }
        ]
      },

      {
        category: "INCOME",
        account_types: [
          {
            account_type: "Income",
            detail_types: [ "Non-Profit Income", "Other Primary Income", "Sales of Product Income", "Service/Fee Income" ],
            description: "Revenue earned from the business's primary products, services, or normal operations."
          },

          {
            account_type: "Other Income",
            description: "Income earned from activities outside the business's primary operations.",
            detail_types: [ "Dividend Income", "Interest Earned", "Other Investment Income", "Other Miscellaneous Income", "Tax-Exempt Interest" ]
          }
        ]
      },

      {
        category: "EXPENSE",
        account_types: [
          {
            account_type: "Cost of Goods Sold",
            description: "Direct costs incurred to produce goods or deliver services sold by the business.",
            detail_types: [ "Equipment Rental", "Labor - COS", "Materials/Supplies - COS", "Other Costs of Services - COS" ]
          },

          {
            account_type: "Expenses",
            description: "Operating costs incurred to run and manage the business.",
            detail_types: [ "Advertising/Promotional", "Auto", "Bank Charges", "Charitable Contributions", "Commissions and Fees", "Dues & Subscriptions", "Insurance", "Legal & Professional Fees", "Office/General Administrative Expenses", "Rent or Lease of Buildings", "Supplies", "Taxes Paid", "Travel", "Utilities" ]
          },

          {
            account_type: "Other Expense",
            description: "Expenses that arise outside the business's normal operating activities.",
            detail_types: [ "Amortization", "Depreciation", "Home Office Expenses", "Other Miscellaneous Expense", "Penalties & Settlements" ]
          }
        ]
      }
    ].freeze

    CORE = {}.freeze
    STARTER_ACCOUNTS = {}.freeze
    RECOMMENDED = {}.freeze
  end
end
