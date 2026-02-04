# frozen_string_literal: true

module DiscourseCustomPlugin
  class CheckinController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in
    before_action :ensure_checkin_enabled
    
    def show
      render json: {
        checked_in_today: current_user.checked_in_today?,
        consecutive_days: current_user.consecutive_checkin_days,
        today_checkin: today_checkin_data,
        stats: checkin_stats
      }
    end
    
    def create
      checkin = UserCheckin.checkin!(current_user)
      
      if checkin
        render json: {
          success: true,
          message: I18n.t("discourse_custom_plugin.checkin.success", points: checkin.points_earned),
          checkin: serialize_checkin(checkin),
          consecutive_days: checkin.consecutive_days
        }
      else
        render json: {
          success: false,
          message: I18n.t("discourse_custom_plugin.checkin.already_checked_in")
        }, status: 422
      end
    end
    
    def history
      page = params[:page].to_i || 0
      per_page = 30
      
      checkins = UserCheckin
        .where(user_id: current_user.id)
        .recent
        .offset(page * per_page)
        .limit(per_page)
      
      render json: {
        checkins: checkins.map { |c| serialize_checkin(c) },
        has_more: checkins.count == per_page
      }
    end
    
    def lottery
      render json: {
        enabled: SiteSetting.checkin_lottery_enabled,
        can_draw: can_draw_lottery?,
        can_buy_draw: can_buy_extra_lottery?,
        extra_draw_cost: SiteSetting.checkin_extra_lottery_cost,
        extra_draws_remaining: extra_draws_remaining,
        user_points: user_total_points,
        prizes: SiteSetting.checkin_lottery_prizes.split("|"),
        today_prize: today_checkin_data&.dig(:lottery_prize)
      }
    end
    
    def draw
      unless can_draw_lottery?
        return render json: {
          success: false,
          message: "No lottery chance available"
        }, status: 422
      end
      
      prize = UserCheckin.lottery!(current_user)
      
      if prize
        render json: {
          success: true,
          prize: prize,
          message: "You won: #{prize}"
        }
      else
        render json: {
          success: false,
          message: "No lottery chance available"
        }, status: 422
      end
    end
    
    # 额外抽奖（消耗积分）
    def extra_draw
      unless can_buy_extra_lottery?
        return render json: {
          success: false,
          message: "Cannot purchase extra lottery"
        }, status: 422
      end
      
      cost = SiteSetting.checkin_extra_lottery_cost
      
      # 扣除积分
      unless deduct_user_points(cost)
        return render json: {
          success: false,
          message: "Insufficient points"
        }, status: 422
      end
      
      # 执行抽奖
      prize = perform_lottery
      
      # 记录额外抽奖
      record_extra_lottery(prize)
      
      render json: {
        success: true,
        prize: prize,
        points_spent: cost,
        remaining_points: user_total_points,
        extra_draws_remaining: extra_draws_remaining
      }
    end
    
    private
    def ensure_checkin_enabled
      return if SiteSetting.custom_plugin_enabled && SiteSetting.checkin_enabled

      raise Discourse::NotFound
    end

    
    def today_checkin_data
      checkin = UserCheckin.today.find_by(user_id: current_user.id)
      return nil unless checkin
      serialize_checkin(checkin)
    end
    
    def checkin_stats
      {
        total_checkins: UserCheckin.where(user_id: current_user.id).count,
        total_points: UserCheckin.where(user_id: current_user.id).sum(:points_earned),
        this_month: UserCheckin.this_month.where(user_id: current_user.id).count,
        this_month_dates: UserCheckin.this_month
          .where(user_id: current_user.id)
          .pluck(:checked_in_at)
          .map { |d| d.to_date.to_s }
      }
    end
    
    def can_draw_lottery?
      return false unless SiteSetting.checkin_lottery_enabled
      return false unless current_user.checked_in_today?
      
      today_checkin = UserCheckin.today.find_by(user_id: current_user.id)
      today_checkin&.lottery_prize.blank?
    end
    
    def can_buy_extra_lottery?
      return false unless SiteSetting.checkin_lottery_enabled
      return false unless current_user.checked_in_today?
      return false if extra_draws_remaining <= 0
      return false if user_total_points < SiteSetting.checkin_extra_lottery_cost
      true
    end
    
    def extra_draws_remaining
      max_draws = SiteSetting.checkin_max_extra_lottery_per_day
      today_draws = DiscourseCustomPlugin::ExtraLotteryRecord.where(user_id: current_user.id)
        .where("created_at >= ?", Date.current.beginning_of_day)
        .count
      [max_draws - today_draws, 0].max
    end
    
    def user_total_points
      UserCheckin.where(user_id: current_user.id).sum(:points_earned)
    end
    
    def deduct_user_points(amount)
      return false if user_total_points < amount
      
      # 创建负积分记录
      UserCheckin.create!(
        user_id: current_user.id,
        checked_in_at: Time.current,
        points_earned: -amount,
        consecutive_days: 0,
        lottery_prize: "Points spent on lottery"
      )
      true
    end
    
    def perform_lottery
      prizes = SiteSetting.checkin_lottery_prizes.split("|")
      probabilities = SiteSetting.checkin_lottery_probabilities.split("|").map(&:to_i)
      
      total = probabilities.sum
      random = rand(total)
      cumulative = 0
      
      prizes.each_with_index do |prize, index|
        cumulative += probabilities[index] || 10
        return prize if random < cumulative
      end
      
      prizes.last
    end
    
    def record_extra_lottery(prize)
      DiscourseCustomPlugin::ExtraLotteryRecord.create!(
        user_id: current_user.id,
        prize: prize,
        points_spent: SiteSetting.checkin_extra_lottery_cost
      )
    end
    
    def serialize_checkin(checkin)
      {
        id: checkin.id,
        checked_in_at: checkin.checked_in_at,
        points_earned: checkin.points_earned,
        consecutive_days: checkin.consecutive_days,
        lottery_prize: checkin.lottery_prize
      }
    end
  end
end
