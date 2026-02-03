# frozen_string_literal: true

# name: discourse-custom-plugin
# about: Custom plugin with daily check-in, todo list, badges wall, and custom emoji
# version: 1.0.0
# authors: Custom Development
# url: https://github.com/urizenk/discourse-custom-plugin
# required_version: 2.7.0

enabled_site_setting :custom_plugin_enabled

register_asset "stylesheets/custom-plugin.scss"

after_initialize do
  # ==========================================
  # 模块加载
  # ==========================================
  
  module ::DiscourseCustomPlugin
    PLUGIN_NAME = "discourse-custom-plugin"
    
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseCustomPlugin
    end
  end

  # ==========================================
  # 加载模型
  # ==========================================
  
  require_relative "app/models/user_checkin"
  require_relative "app/models/user_todo"
  require_relative "app/models/user_badge_collection"
  require_relative "app/models/custom_emoji"
  
  # ==========================================
  # 加载控制器
  # ==========================================
  
  require_relative "app/controllers/checkin_controller"
  require_relative "app/controllers/todos_controller"
  require_relative "app/controllers/badge_wall_controller"
  require_relative "app/controllers/custom_emoji_controller"
  
  # ==========================================
  # 路由配置
  # ==========================================
  
  DiscourseCustomPlugin::Engine.routes.draw do
    # 签到系统
    get "/checkin" => "checkin#show"
    post "/checkin" => "checkin#create"
    get "/checkin/history" => "checkin#history"
    get "/checkin/lottery" => "checkin#lottery"
    post "/checkin/draw" => "checkin#draw"
    
    # To Do List
    resources :todos, only: [:index, :create, :update, :destroy] do
      member do
        put :toggle
        put :reorder
      end
    end
    
    # 徽章墙
    get "/badge-wall" => "badge_wall#index"
    get "/badge-wall/:user_id" => "badge_wall#show"
    post "/badge-wall/collect/:badge_id" => "badge_wall#collect"
    
    # 自定义表情
    get "/custom-emoji" => "custom_emoji#index"
    post "/custom-emoji" => "custom_emoji#create"
    delete "/custom-emoji/:id" => "custom_emoji#destroy"
  end

  Discourse::Application.routes.append do
    mount ::DiscourseCustomPlugin::Engine, at: "/custom-plugin"
  end

  # ==========================================
  # 用户扩展
  # ==========================================
  
  add_to_class(:user, :checkins) do
    return DiscourseCustomPlugin::UserCheckin.none unless ActiveRecord::Base.connection.table_exists?(:user_checkins)
    DiscourseCustomPlugin::UserCheckin.where(user_id: id)
  rescue
    DiscourseCustomPlugin::UserCheckin.none
  end
  
  add_to_class(:user, :todos) do
    return DiscourseCustomPlugin::UserTodo.none unless ActiveRecord::Base.connection.table_exists?(:user_todos)
    DiscourseCustomPlugin::UserTodo.where(user_id: id)
  rescue
    DiscourseCustomPlugin::UserTodo.none
  end
  
  add_to_class(:user, :badge_collections) do
    return DiscourseCustomPlugin::UserBadgeCollection.none unless ActiveRecord::Base.connection.table_exists?(:user_badge_collections)
    DiscourseCustomPlugin::UserBadgeCollection.where(user_id: id)
  rescue
    DiscourseCustomPlugin::UserBadgeCollection.none
  end
  
  add_to_class(:user, :custom_emojis) do
    return DiscourseCustomPlugin::CustomEmoji.none unless ActiveRecord::Base.connection.table_exists?(:plugin_custom_emojis)
    DiscourseCustomPlugin::CustomEmoji.where(user_id: id)
  rescue
    DiscourseCustomPlugin::CustomEmoji.none
  end
  
  add_to_class(:user, :checked_in_today?) do
    return false unless ActiveRecord::Base.connection.table_exists?(:user_checkins)
    DiscourseCustomPlugin::UserCheckin.exists?(
      user_id: id,
      checked_in_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day
    )
  rescue
    false
  end
  
  add_to_class(:user, :consecutive_checkin_days) do
    return 0 unless ActiveRecord::Base.connection.table_exists?(:user_checkins)
    checkins = DiscourseCustomPlugin::UserCheckin
      .where(user_id: id)
      .order(checked_in_at: :desc)
      .pluck(:checked_in_at)
    
    return 0 if checkins.empty?
    
    days = 1
    checkins.each_cons(2) do |current, previous|
      if (current.to_date - previous.to_date).to_i == 1
        days += 1
      else
        break
      end
    end
    days
  rescue
    0
  end

  # ==========================================
  # 序列化器扩展
  # ==========================================
  
  add_to_serializer(:current_user, :checked_in_today) do
    return false unless object
    return false unless ActiveRecord::Base.connection.table_exists?(:user_checkins)
    object.checked_in_today?
  rescue
    false
  end
  
  add_to_serializer(:current_user, :consecutive_checkin_days) do
    return 0 unless object
    return 0 unless ActiveRecord::Base.connection.table_exists?(:user_checkins)
    object.consecutive_checkin_days
  rescue
    0
  end
  
  add_to_serializer(:current_user, :todo_count) do
    return 0 unless object
    return 0 unless ActiveRecord::Base.connection.table_exists?(:user_todos)
    object.todos.where(completed: false).count
  rescue
    0
  end
  
  add_to_serializer(:current_user, :badge_collection_count) do
    return 0 unless object
    return 0 unless ActiveRecord::Base.connection.table_exists?(:user_badge_collections)
    object.badge_collections.count
  rescue
    0
  end
end
