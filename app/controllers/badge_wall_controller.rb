# frozen_string_literal: true

module DiscourseCustomPlugin
  class BadgeWallController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in, except: [:show, :index]
    before_action :ensure_badge_wall_enabled
    
    def index
      # 支持查看其他用户的徽章墙
      target_user = if params[:user_id].present?
        User.find_by(id: params[:user_id])
      else
        current_user
      end
      
      # 如果没有找到用户，返回空数据
      unless target_user
        return render json: { collections: [], earned_badges: [], all_badges: [], stats: { collected: 0, earned: 0, total: 0 } }
      end
      
      # 获取目标用户已收藏的徽章
      collections = UserBadgeCollection
        .where(user_id: target_user.id)
        .includes(:badge)
        .ordered
      
      # 获取用户已获得的所有徽章
      earned_badges = UserBadge
        .where(user_id: target_user.id)
        .includes(:badge)
        .map(&:badge)
        .uniq
      
      # 获取所有可收藏的徽章
      all_badges = Badge.enabled
      
      render json: {
        collections: collections.map { |c| serialize_collection(c) },
        earned_badges: earned_badges.map { |b| serialize_badge(b, target_user) },
        all_badges: all_badges.map { |b| serialize_badge(b, target_user) },
        stats: {
          collected: collections.count,
          earned: earned_badges.count,
          total: all_badges.count
        }
      }
    end
    
    def show
      user = User.find(params[:user_id])
      
      # 检查隐私设置
      unless SiteSetting.badge_wall_public || user.id == current_user&.id
        return render json: { error: "Private" }, status: 403
      end
      
      collections = UserBadgeCollection
        .where(user_id: user.id)
        .displayed
        .includes(:badge)
        .ordered
      
      render json: {
        user: BasicUserSerializer.new(user, root: false).as_json,
        collections: collections.map { |c| serialize_collection(c) },
        stats: {
          collected: collections.count
        }
      }
    end
    
    def collect
      badge = Badge.find(params[:badge_id])
      result = UserBadgeCollection.collect!(current_user, badge)
      
      if result[:success]
        render json: {
          success: true,
          message: I18n.t("discourse_custom_plugin.badge_wall.collected"),
          collection: serialize_collection(result[:collection])
        }
      else
        error_message = case result[:error]
        when :not_earned
          I18n.t("discourse_custom_plugin.badge_wall.not_earned")
        when :already_collected
          I18n.t("discourse_custom_plugin.badge_wall.already_collected")
        else
          result[:error].to_s
        end
        
        render json: {
          success: false,
          message: error_message
        }, status: 422
      end
    end
    
    def uncollect
      badge = Badge.find(params[:badge_id])
      result = UserBadgeCollection.uncollect!(current_user, badge)
      
      if result[:success]
        render json: { success: true }
      else
        render json: { success: false }, status: 422
      end
    end
    
    private
    
    def serialize_collection(collection)
      {
        id: collection.id,
        badge: serialize_badge(collection.badge, current_user),
        displayed: collection.displayed,
        position: collection.position,
        collected_at: collection.created_at
      }
    end
    
    def serialize_badge(badge, user = nil)
      earned = user ? UserBadge.exists?(user_id: user.id, badge_id: badge.id) : false
      collected = user ? UserBadgeCollection.exists?(user_id: user.id, badge_id: badge.id) : false
      
      {
        id: badge.id,
        name: badge.name,
        description: badge.description,
        icon: badge.icon,
        image_url: badge.image_url,
        badge_type_id: badge.badge_type_id,
        earned: earned,
        collected: collected
      }
    end
    def ensure_badge_wall_enabled
      return if SiteSetting.custom_plugin_enabled && SiteSetting.badge_wall_enabled

      raise Discourse::NotFound
    end

  end
end
