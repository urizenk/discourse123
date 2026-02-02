# frozen_string_literal: true

module DiscourseCustomPlugin
  class UserTodo < ActiveRecord::Base
    self.table_name = "user_todos"
    
    belongs_to :user
    
    validates :user_id, presence: true
    validates :title, presence: true, length: { maximum: 255 }
    validates :list_type, inclusion: { in: %w[todo wish] }
    validates :priority, inclusion: { in: [0, 1, 2] }
    
    scope :todos, -> { where(list_type: "todo") }
    scope :wishes, -> { where(list_type: "wish") }
    scope :pending, -> { where(completed: false) }
    scope :completed, -> { where(completed: true) }
    scope :ordered, -> { order(position: :asc, created_at: :desc) }
    scope :by_priority, -> { order(priority: :desc, position: :asc) }
    
    before_create :set_position
    
    def toggle!
      update!(completed: !completed)
    end
    
    def move_to(new_position)
      return if position == new_position
      
      if new_position < position
        # 向上移动
        self.class.where(user_id: user_id, list_type: list_type)
          .where("position >= ? AND position < ?", new_position, position)
          .update_all("position = position + 1")
      else
        # 向下移动
        self.class.where(user_id: user_id, list_type: list_type)
          .where("position > ? AND position <= ?", position, new_position)
          .update_all("position = position - 1")
      end
      
      update!(position: new_position)
    end
    
    private
    
    def set_position
      max_position = self.class.where(user_id: user_id, list_type: list_type).maximum(:position) || -1
      self.position = max_position + 1
    end
  end
end
