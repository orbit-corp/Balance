class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :account_type, null: false
      t.string :account_subtype, null: false
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :accounts, [ :workspace_id, :account_type ]
    add_index :accounts, [ :workspace_id, :account_type, :account_subtype, :name ], unique: true

    create_table :customers do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :phone

      t.timestamps
    end
    add_index :customers, :phone

    create_table :linking_tokens do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at

      t.timestamps
    end
    add_index :linking_tokens, :token, unique: true

    create_table :whatsapp_links do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :wa_id, null: false
      t.string :phone_number_id
      t.string :profile_name
      t.integer :status, null: false, default: 0
      t.datetime :requested_at
      t.datetime :linked_at
      t.datetime :last_message_at

      t.timestamps
    end
    add_index :whatsapp_links, :wa_id, unique: true, where: "status = 1", name: "idx_whatsapp_links_active_wa_id"

    create_table :whatsapp_processed_messages do |t|
      t.string :wamid, null: false

      t.timestamps
    end
    add_index :whatsapp_processed_messages, :wamid, unique: true

    create_table :campaigns do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end
    add_index :campaigns, [ :workspace_id, :status ]

    create_table :campaign_channels do |t|
      t.references :campaign, null: false, foreign_key: true
      t.integer :platform, null: false
      t.string :destination_url, null: false

      t.timestamps
    end
    add_index :campaign_channels, [ :campaign_id, :platform ]

    create_table :shortlinks do |t|
      t.references :campaign_channel, null: false, foreign_key: true
      t.string :host, null: false
      t.string :slug, null: false
      t.string :ref_code, null: false
      t.string :label
      t.integer :status, null: false, default: 0

      t.timestamps
    end
    add_index :shortlinks, [ :host, :slug ], unique: true
    add_index :shortlinks, :ref_code, unique: true

    create_table :whatsapp_messages do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :whatsapp_link, null: true, foreign_key: true
      t.string :wamid, null: false
      t.integer :direction, null: false, default: 0
      t.string :message_type, null: false
      t.text :body
      t.string :media_id
      t.datetime :sent_at
      t.integer :media_status, null: false, default: 0
      t.integer :classification_status, null: false, default: 0
      t.references :matched_shortlink, foreign_key: { to_table: :shortlinks }

      t.timestamps
    end
    add_index :whatsapp_messages, :wamid, unique: true
    add_index :whatsapp_messages, [ :workspace_id, :sent_at ]

    create_table :journal_entries do |t|
      t.references :workspace, null: false, foreign_key: true
      t.date :entry_date, null: false
      t.text :description

      t.timestamps
    end
    add_index :journal_entries, [ :workspace_id, :entry_date ]

    create_table :journal_entry_lines do |t|
      t.references :journal_entry, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.bigint :debit_kobo, null: false, default: 0
      t.bigint :credit_kobo, null: false, default: 0

      t.timestamps
    end

    create_table :whatsapp_document_extractions do |t|
      t.references :whatsapp_message, null: false, foreign_key: true, index: { unique: true }
      t.references :journal_entry, null: true, foreign_key: true

      t.integer :document_type, null: false, default: 0
      t.integer :review_status, null: false, default: 0
      t.integer :direction_guess, null: false, default: 0

      t.string :currency
      t.boolean :currency_supported, null: false, default: false
      t.integer :amount_kobo

      t.string :sender_name
      t.string :recipient_name
      t.string :recipient_bank
      t.string :reference_number
      t.date :transaction_date
      t.text :narration

      t.float :confidence
      t.text :raw_text

      t.timestamps
    end

    create_table :clicks do |t|
      t.references :shortlink, null: false, foreign_key: true
      t.string :ref_code, null: false
      t.datetime :occurred_at, null: false
      t.string :ip_address
      t.string :user_agent
      t.string :referrer
      t.boolean :bot, null: false, default: false

      t.timestamps
    end
    add_index :clicks, [ :shortlink_id, :occurred_at ]

    create_table :conversions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :shortlink, foreign_key: true
      t.integer :amount_kobo, null: false
      t.integer :kind, null: false, default: 1
      t.integer :confirmation_status, null: false, default: 0
      t.integer :source, null: false, default: 0
      t.datetime :occurred_at, null: false
      t.references :campaign, foreign_key: true

      t.timestamps
    end
    add_index :conversions, [ :workspace_id, :created_at ]

    primary_key_type, foreign_key_type = primary_and_foreign_key_types

    create_table :active_storage_blobs, id: primary_key_type do |t|
      t.string   :key,          null: false
      t.string   :filename,     null: false
      t.string   :content_type
      t.text     :metadata
      t.string   :service_name, null: false
      t.bigint   :byte_size,    null: false
      t.string   :checksum

      if connection.supports_datetime_with_precision?
        t.datetime :created_at, precision: 6, null: false
      else
        t.datetime :created_at, null: false
      end

      t.index [ :key ], unique: true
    end

    create_table :active_storage_attachments, id: primary_key_type do |t|
      t.string     :name,     null: false
      t.references :record,   null: false, polymorphic: true, index: false, type: foreign_key_type
      t.references :blob,     null: false, type: foreign_key_type

      if connection.supports_datetime_with_precision?
        t.datetime :created_at, precision: 6, null: false
      else
        t.datetime :created_at, null: false
      end

      t.index [ :record_type, :record_id, :name, :blob_id ], name: :index_active_storage_attachments_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end

    create_table :active_storage_variant_records, id: primary_key_type do |t|
      t.belongs_to :blob, null: false, index: false, type: foreign_key_type
      t.string :variation_digest, null: false

      t.index [ :blob_id, :variation_digest ], name: :index_active_storage_variant_records_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end
  end

  private
    def primary_and_foreign_key_types
      config = Rails.configuration.generators
      setting = config.options[config.orm][:primary_key_type]
      primary_key_type = setting || :primary_key
      foreign_key_type = setting || :bigint
      [ primary_key_type, foreign_key_type ]
    end
end
