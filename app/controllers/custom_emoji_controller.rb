# frozen_string_literal: true

module DiscourseCustomPlugin
  class CustomEmojiController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in
    before_action :ensure_custom_emoji_enabled
    
    def index
      emojis = CustomEmoji
        .where(user_id: current_user.id)
        .recent
      
      render json: {
        emojis: emojis.map { |e| serialize_emoji(e) },
        stats: {
          count: emojis.count,
          max: SiteSetting.custom_emoji_max_per_user
        }
      }
    end
    
    def create
      upload_id = params[:upload_id]
      name = params[:name]
      
      upload = Upload.find_by(id: upload_id)
      
      unless upload
        return render json: {
          success: false,
          message: "Upload not found"
        }, status: 422
      end
      
      result = CustomEmoji.create_from_upload!(current_user, upload, name)
      
      if result[:success]
        render json: {
          success: true,
          message: I18n.t("discourse_custom_plugin.custom_emoji.uploaded"),
          emoji: serialize_emoji(result[:emoji])
        }
      else
        error_message = case result[:error]
        when :max_reached
          I18n.t("discourse_custom_plugin.custom_emoji.max_reached")
        when :file_too_large
          I18n.t("discourse_custom_plugin.custom_emoji.file_too_large")
        else
          result[:error].to_s
        end
        
        render json: {
          success: false,
          message: error_message
        }, status: 422
      end
    end
    
    def destroy
      emoji = CustomEmoji.find_by!(id: params[:id], user_id: current_user.id)
      emoji.destroy!
      
      render json: {
        success: true,
        message: I18n.t("discourse_custom_plugin.custom_emoji.deleted")
      }
    rescue ActiveRecord::RecordNotFound
      render json: { success: false, error: "Not found" }, status: 404
    end
    
    private
    
    def serialize_emoji(emoji)
      {
        id: emoji.id,
        name: emoji.name,
        url: emoji.url,
        emoji_code: emoji.emoji_code,
        usage_count: emoji.usage_count,
        created_at: emoji.created_at
      }
    end
    def ensure_custom_emoji_enabled
      return if SiteSetting.custom_plugin_enabled && SiteSetting.custom_emoji_enabled

      raise Discourse::NotFound
    end

  end
end
