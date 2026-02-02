# frozen_string_literal: true

class CreateUserBadgeCollections < ActiveRecord::Migration[7.0]
  def change
    create_table :user_badge_collections do |t|
      t.integer :user_id, null: false
      t.integer :badge_id, null: false
      t.boolean :displayed, default: true
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :user_badge_collections, :user_id
    add_index :user_badge_collections, :badge_id
    add_index :user_badge_collections, [:user_id, :badge_id], unique: true
  end
end
