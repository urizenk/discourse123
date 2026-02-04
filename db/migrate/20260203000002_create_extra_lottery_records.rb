# frozen_string_literal: true

class CreateExtraLotteryRecords < ActiveRecord::Migration[7.0]
  def change
    create_table :extra_lottery_records do |t|
      t.integer :user_id, null: false
      t.string :prize, null: false
      t.integer :points_spent, default: 0
      t.timestamps
    end
    
    add_index :extra_lottery_records, :user_id
    add_index :extra_lottery_records, :created_at
  end
end
