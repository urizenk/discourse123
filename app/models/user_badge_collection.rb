# frozen_string_literal: true

module DiscourseCustomPlugin
  class UserBadgeCollection < ActiveRecord::Base
    self.table_name = "user_badge_collections"
    
    belongs_to :user
    belongs_to :badge
    
    validates :user_id, presence: true
    validates :badge_id, presence: true
    validates :badge_id, uniqueness: { scope: :user_id, message: "该徽章已在收藏中" }
    
    scope :displayed, -> { where(displayed: true) }
    scope :ordered, -> { order(position: :asc) }
    
    before_create :check_user_earned_badge
    before_create :set_position
    
    def self.collect!(user, badge)
      # 检查用户是否已获得该徽章
      unless UserBadge.exists?(user_id: user.id, badge_id: badge.id)
        return { success: false, error: :not_earned }
      end
      
      # 检查是否已收藏
      if exists?(user_id: user.id, badge_id: badge.id)
        return { success: false, error: :already_collected }
      end
      
      collection = create!(user_id: user.id, badge_id: badge.id)
      { success: true, collection: collection }
    rescue => e
      { success: false, error: e.message }
    end
    
    def self.uncollect!(user, badge)
      collection = find_by(user_id: user.id, badge_id: badge.id)
      return { success: false, error: :not_found } unless collection
      
      collection.destroy!
      { success: true }
    end
    
    private
    
    def check_user_earned_badge
      unless UserBadge.exists?(user_id: user_id, badge_id: badge_id)
        errors.add(:badge_id, "您尚未获得该徽章")
        throw(:abort)
      end
    end
    
    def set_position
      max_position = self.class.where(user_id: user_id).maximum(:position) || -1
      self.position = max_position + 1
    end
  end
end
