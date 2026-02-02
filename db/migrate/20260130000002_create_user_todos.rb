# frozen_string_literal: true

class CreateUserTodos < ActiveRecord::Migration[7.0]
  def change
    create_table :user_todos do |t|
      t.integer :user_id, null: false
      t.string :title, null: false
      t.text :description
      t.boolean :completed, default: false
      t.integer :position, default: 0
      t.string :list_type, default: "todo" # todo 或 wish
      t.date :due_date
      t.integer :priority, default: 0 # 0: 普通, 1: 重要, 2: 紧急
      t.timestamps
    end

    add_index :user_todos, :user_id
    add_index :user_todos, [:user_id, :list_type]
    add_index :user_todos, [:user_id, :completed]
  end
end
