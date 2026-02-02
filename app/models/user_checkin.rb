# frozen_string_literal: true

module DiscourseCustomPlugin
  class UserCheckin < ActiveRecord::Base
    self.table_name = "user_checkins"
    
    belongs_to :user
    
    validates :user_id, presence: true
    validates :checked_in_at, presence: true
    validates :user_id, uniqueness: { 
      scope: :checked_in_at,
      message: "今天已经签到过了"
    }
    
    scope :today, -> { where(checked_in_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day) }
    scope :this_month, -> { where(checked_in_at: Time.zone.now.beginning_of_month..Time.zone.now.end_of_month) }
    scope :recent, -> { order(checked_in_at: :desc) }
    
    before_create :calculate_consecutive_days
    before_create :calculate_points
    
    def self.checkin!(user)
      return nil if user.checked_in_today?
      
      checkin = new(
        user_id: user.id,
        checked_in_at: Time.zone.now
      )
      
      if checkin.save
        # 触发积分奖励
        if defined?(DiscourseGamification)
          DiscourseGamification.trigger_score(user, :checkin, checkin.points_earned)
        end
        checkin
      else
        nil
      end
    end
    
    def self.lottery!(user)
      return nil unless SiteSetting.checkin_lottery_enabled
      
      today_checkin = today.find_by(user_id: user.id)
      return nil unless today_checkin
      return nil if today_checkin.lottery_prize.present?
      
      prizes = SiteSetting.checkin_lottery_prizes.split("|")
      probabilities = SiteSetting.checkin_lottery_probabilities.split("|").map(&:to_i)
      
      prize = weighted_random(prizes, probabilities)
      today_checkin.update!(lottery_prize: prize)
      
      prize
    end
    
    private
    
    def calculate_consecutive_days
      yesterday = Time.zone.now.yesterday
      yesterday_checkin = self.class.where(user_id: user_id)
        .where(checked_in_at: yesterday.beginning_of_day..yesterday.end_of_day)
        .exists?
      
      if yesterday_checkin
        last_consecutive = self.class.where(user_id: user_id)
          .order(checked_in_at: :desc)
          .first
          &.consecutive_days || 0
        self.consecutive_days = last_consecutive + 1
      else
        self.consecutive_days = 1
      end
    end
    
    def calculate_points
      base_points = SiteSetting.checkin_base_points
      bonus = SiteSetting.checkin_consecutive_bonus
      
      self.points_earned = base_points + (consecutive_days - 1) * bonus
    end
    
    def self.weighted_random(items, weights)
      total = weights.sum
      random = rand(total)
      
      cumulative = 0
      items.each_with_index do |item, index|
        cumulative += weights[index]
        return item if random < cumulative
      end
      
      items.last
    end
  end
end
