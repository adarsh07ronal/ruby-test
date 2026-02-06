class CreateSubscriptionEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_events do |t|
      t.references :subscription, foreign_key: true

      t.string :event_type, null: false
      t.string :transaction_id, null: false
      t.string :product_id

      t.decimal :amount, precision: 8, scale: 2
      t.string :currency

      t.datetime :purchase_date
      t.datetime :expires_date

      t.timestamps
    end

    add_index :subscription_events,
      [:transaction_id, :event_type, :purchase_date],
      unique: true,
      name: "idx_subscription_events_idempotency"
  end
end
