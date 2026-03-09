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
        stats: checkin_stats,
        accumulated_draws: accumulated_draws_count
      }
    end

    def create
      checkin = UserCheckin.checkin!(current_user)

      if checkin
        add_gamification_points(current_user, checkin.points_earned, "daily_checkin")

        render json: {
          success: true,
          message: I18n.t("discourse_custom_plugin.checkin.success", points: checkin.points_earned),
          checkin: serialize_checkin(checkin),
          consecutive_days: checkin.consecutive_days,
          accumulated_draws: accumulated_draws_count
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
        prizes: lottery_prize_config,
        today_prize: today_checkin_data&.dig(:lottery_prize),
        accumulated_draws: accumulated_draws_count,
        product_reward_name: SiteSetting.checkin_product_reward_name,
        product_reward_image: SiteSetting.checkin_product_reward_image_url
      }
    end

    def draw
      unless can_draw_lottery?
        return render json: { success: false, message: "No lottery chance available" }, status: 422
      end

      prize = perform_lottery
      points_won = extract_points(prize)

      today_checkin = UserCheckin.today.find_by(user_id: current_user.id)
      if today_checkin&.lottery_prize.blank?
        today_checkin.update!(lottery_prize: prize)
      end

      if points_won > 0
        add_gamification_points(current_user, points_won, "lottery_win")
      end

      if prize == "Product Reward"
        notify_product_winner(current_user, prize)
      end

      decrement_accumulated_draws

      render json: {
        success: true,
        prize: prize,
        points_won: points_won,
        accumulated_draws: accumulated_draws_count,
        message: "You won: #{prize}"
      }
    end

    def extra_draw
      unless can_buy_extra_lottery?
        return render json: { success: false, message: "Cannot purchase extra lottery" }, status: 422
      end

      cost = SiteSetting.checkin_extra_lottery_cost
      unless deduct_user_points(cost)
        return render json: { success: false, message: "Insufficient points" }, status: 422
      end

      prize = perform_lottery
      points_won = extract_points(prize)

      if points_won > 0
        add_gamification_points(current_user, points_won, "extra_lottery_win")
      end

      if prize == "Product Reward"
        notify_product_winner(current_user, prize)
      end

      record_extra_lottery(prize)

      render json: {
        success: true,
        prize: prize,
        points_won: points_won,
        points_spent: cost,
        remaining_points: user_total_points,
        extra_draws_remaining: extra_draws_remaining
      }
    end

    private

    def ensure_checkin_enabled
      raise Discourse::NotFound unless SiteSetting.custom_plugin_enabled && SiteSetting.checkin_enabled
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

    def accumulated_draws_count
      return 0 unless current_user.checked_in_today?
      today_checkin = UserCheckin.today.find_by(user_id: current_user.id)
      return 0 unless today_checkin
      today_checkin.lottery_prize.blank? ? 1 : 0
    end

    def decrement_accumulated_draws
      # Draws are consumed by setting lottery_prize on the checkin record
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
      today_draws = ExtraLotteryRecord.where(user_id: current_user.id)
        .where("created_at >= ?", Date.current.beginning_of_day)
        .count
      [max_draws - today_draws, 0].max
    end

    def user_total_points
      UserCheckin.where(user_id: current_user.id).sum(:points_earned)
    end

    def deduct_user_points(amount)
      return false if user_total_points < amount
      UserCheckin.create!(
        user_id: current_user.id,
        checked_in_at: Time.current,
        points_earned: -amount,
        consecutive_days: 0,
        lottery_prize: "Points spent on lottery"
      )
      true
    end

    def lottery_prize_config
      prizes = SiteSetting.checkin_lottery_prizes.split("|")
      probabilities = SiteSetting.checkin_lottery_probabilities.split("|").map(&:to_i)
      prizes.each_with_index.map do |prize, i|
        { name: prize, probability: probabilities[i] || 0 }
      end
    end

    def perform_lottery
      if should_force_weekly_product_winner?
        return product_prize_label
      end

      prizes = SiteSetting.checkin_lottery_prizes.split("|")
      probabilities = SiteSetting.checkin_lottery_probabilities.split("|").map(&:to_i)

      total = probabilities.sum
      random = rand(total)
      cumulative = 0

      prizes.each_with_index do |prize, index|
        cumulative += probabilities[index] || 0
        return prize if random < cumulative
      end

      prizes.last
    end

    def should_force_weekly_product_winner?
      return false unless SiteSetting.checkin_weekly_winner_enabled

      week_start = Date.current.beginning_of_week
      week_end = Date.current.end_of_week
      today = Date.current
      day_of_week = today.cwday # 1=Mon, 7=Sun

      return false if product_winner_this_week?(week_start, week_end)

      # Escalating probability: Mon-Thu 5%, Fri 20%, Sat 50%, Sun 100%
      force_chance = case day_of_week
                     when 1..4 then 5
                     when 5 then 20
                     when 6 then 50
                     when 7 then 100
                     else 5
                     end

      rand(100) < force_chance
    end

    def product_winner_this_week?(week_start, week_end)
      product_label = product_prize_label
      UserCheckin
        .where(checked_in_at: week_start.beginning_of_day..week_end.end_of_day)
        .where(lottery_prize: product_label)
        .exists? ||
      ExtraLotteryRecord
        .where(created_at: week_start.beginning_of_day..week_end.end_of_day)
        .where(prize: product_label)
        .exists?
    end

    def product_prize_label
      prizes = SiteSetting.checkin_lottery_prizes.split("|")
      prizes.find { |p| p.downcase.include?("product") } || "Product Reward"
    end

    def extract_points(prize)
      match = prize.match(/(\d+)\s*Points?/i)
      match ? match[1].to_i : 0
    end

    def add_gamification_points(user, points, reason)
      return unless points > 0
      return unless defined?(DiscourseGamification::GamificationScoreEvent)

      begin
        DiscourseGamification::GamificationScoreEvent.create!(
          user_id: user.id,
          date: Date.current,
          points: points,
          description: reason
        )
      rescue => e
        Rails.logger.warn("Failed to add gamification points: #{e.message}")
      end
    end

    def notify_product_winner(user, prize)
      product_name = SiteSetting.checkin_product_reward_name.presence || "Product Reward"

      begin
        PostCreator.create!(
          Discourse.system_user,
          target_usernames: user.username,
          archetype: Archetype.private_message,
          title: I18n.t("discourse_custom_plugin.checkin.product_win_title"),
          raw: I18n.t("discourse_custom_plugin.checkin.product_win_body", product: product_name, username: user.username)
        )

        admin_usernames = User.where(admin: true).pluck(:username).join(",")
        if admin_usernames.present?
          PostCreator.create!(
            Discourse.system_user,
            target_usernames: admin_usernames,
            archetype: Archetype.private_message,
            title: I18n.t("discourse_custom_plugin.checkin.admin_notify_title"),
            raw: I18n.t("discourse_custom_plugin.checkin.admin_notify_body", product: product_name, username: user.username)
          )
        end
      rescue => e
        Rails.logger.warn("Failed to send product win notification: #{e.message}")
      end
    end

    def record_extra_lottery(prize)
      ExtraLotteryRecord.create!(
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
