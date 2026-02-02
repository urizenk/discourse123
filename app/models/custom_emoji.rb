# frozen_string_literal: true

module DiscourseCustomPlugin
  class CustomEmoji < ActiveRecord::Base
    self.table_name = "custom_emojis"
    
    belongs_to :user
    belongs_to :upload, optional: true
    
    validates :user_id, presence: true
    validates :name, presence: true, length: { maximum: 50 }
    validates :name, format: { with: /\A[a-z0-9_]+\z/, message: "只能包含小写字母、数字和下划线" }
    validates :name, uniqueness: { scope: :user_id, message: "表情名称已存在" }
    validates :url, presence: true
    
    scope :recent, -> { order(created_at: :desc) }
    scope :popular, -> { order(usage_count: :desc) }
    
    before_validation :normalize_name
    before_create :check_user_limit
    
    def self.create_from_upload!(user, upload, name)
      # 检查用户限制
      max_emojis = SiteSetting.custom_emoji_max_per_user
      if where(user_id: user.id).count >= max_emojis
        return { success: false, error: :max_reached }
      end
      
      # 检查文件大小
      max_size = SiteSetting.custom_emoji_max_size_kb * 1024
      if upload.filesize > max_size
        return { success: false, error: :file_too_large }
      end
      
      emoji = create!(
        user_id: user.id,
        name: name,
        url: upload.url,
        upload_id: upload.id
      )
      
      { success: true, emoji: emoji }
    rescue => e
      { success: false, error: e.message }
    end
    
    def increment_usage!
      increment!(:usage_count)
    end
    
    def emoji_code
      ":#{user.username}_#{name}:"
    end
    
    private
    
    def normalize_name
      self.name = name.to_s.downcase.gsub(/[^a-z0-9_]/, "_").squeeze("_")
    end
    
    def check_user_limit
      max_emojis = SiteSetting.custom_emoji_max_per_user
      if self.class.where(user_id: user_id).count >= max_emojis
        errors.add(:base, "已达到最大表情数量限制")
        throw(:abort)
      end
    end
  end
end
