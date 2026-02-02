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
        prizes: SiteSetting.checkin_lottery_prizes.split("|"),
        today_prize: today_checkin_data&.dig(:lottery_prize)
      }
    end
    
    def draw
      unless can_draw_lottery?
        return render json: {
          success: false,
          message: I18n.t("discourse_custom_plugin.checkin.lottery_no_chance")
        }, status: 422
      end
      
      prize = UserCheckin.lottery!(current_user)
      
      if prize
        render json: {
          success: true,
          prize: prize,
          message: I18n.t("discourse_custom_plugin.checkin.lottery_win", prize: prize)
        }
      else
        render json: {
          success: false,
          message: I18n.t("discourse_custom_plugin.checkin.lottery_no_chance")
        }, status: 422
      end
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
