# frozen_string_literal: true

class CreateUserCheckins < ActiveRecord::Migration[7.0]
  def change
    create_table :user_checkins do |t|
      t.integer :user_id, null: false
      t.datetime :checked_in_at, null: false
      t.integer :points_earned, default: 0
      t.integer :consecutive_days, default: 1
      t.string :lottery_prize
      t.timestamps
    end

    add_index :user_checkins, :user_id
    add_index :user_checkins, :checked_in_at
    add_index :user_checkins, [:user_id, :checked_in_at], unique: true
  end
end
