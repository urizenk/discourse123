# frozen_string_literal: true

class CreatePluginCustomEmojis < ActiveRecord::Migration[7.0]
  def change
    create_table :plugin_custom_emojis do |t|
      t.integer :user_id, null: false
      t.string :name, null: false
      t.string :url, null: false
      t.integer :upload_id
      t.integer :usage_count, default: 0
      t.timestamps
    end

    add_index :plugin_custom_emojis, :user_id
    add_index :plugin_custom_emojis, [:user_id, :name], unique: true
  end
end
