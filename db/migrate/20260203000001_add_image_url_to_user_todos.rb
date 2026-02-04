# frozen_string_literal: true

class AddImageUrlToUserTodos < ActiveRecord::Migration[7.0]
  def change
    add_column :user_todos, :image_url, :string
  end
end
