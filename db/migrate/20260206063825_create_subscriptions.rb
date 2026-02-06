class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.string :user_id, null: false
      t.string :transaction_id, null: false
      t.string :product_id, null: false
      t.string :status, null: false

      t.datetime :current_period_start
      t.datetime :current_period_end

      t.timestamps
    end

    add_index :subscriptions, :transaction_id, unique: true
  end
end
