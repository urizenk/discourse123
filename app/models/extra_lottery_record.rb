# frozen_string_literal: true

module DiscourseCustomPlugin
  class ExtraLotteryRecord < ::ActiveRecord::Base
    self.table_name = "extra_lottery_records"
    
    belongs_to :user
    
    validates :user_id, presence: true
    validates :prize, presence: true
    validates :points_spent, numericality: { greater_than_or_equal_to: 0 }
    
    scope :today, -> { where("created_at >= ?", Date.current.beginning_of_day) }
    scope :recent, -> { order(created_at: :desc) }
  end
end
