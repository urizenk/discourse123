# frozen_string_literal: true

module DiscourseCustomPlugin
  class TodosController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_logged_in, except: [:index]
    before_action :ensure_todo_enabled
    before_action :find_todo, only: [:update, :destroy, :toggle, :reorder]
    
    def index
      list_type = params[:type] || "todo"
      
      # 支持查看其他用户的待办清单
      target_user = if params[:user_id].present?
        User.find_by(id: params[:user_id])
      else
        current_user
      end
      
      # 如果没有找到用户，返回空数据
      unless target_user
        return render json: { todos: [], stats: { total: 0, completed: 0, pending: 0 } }
      end
      
      todos = UserTodo
        .where(user_id: target_user.id, list_type: list_type)
        .ordered
      
      render json: {
        todos: todos.map { |t| serialize_todo(t) },
        stats: {
          total: todos.count,
          completed: todos.completed.count,
          pending: todos.pending.count
        }
      }
    end
    
    def create
      # 检查数量限制
      max_items = SiteSetting.todo_max_items
      current_count = UserTodo.where(user_id: current_user.id).count
      
      if current_count >= max_items
        return render json: {
          success: false,
          message: I18n.t("discourse_custom_plugin.todo.max_reached")
        }, status: 422
      end
      
      todo = UserTodo.new(todo_params.merge(user_id: current_user.id))
      
      if todo.save
        render json: {
          success: true,
          message: I18n.t("discourse_custom_plugin.todo.created"),
          todo: serialize_todo(todo)
        }
      else
        render json: {
          success: false,
          errors: todo.errors.full_messages
        }, status: 422
      end
    end
    
    def update
      if @todo.update(todo_params)
        render json: {
          success: true,
          message: I18n.t("discourse_custom_plugin.todo.updated"),
          todo: serialize_todo(@todo)
        }
      else
        render json: {
          success: false,
          errors: @todo.errors.full_messages
        }, status: 422
      end
    end
    
    def destroy
      @todo.destroy!
      
      render json: {
        success: true,
        message: I18n.t("discourse_custom_plugin.todo.deleted")
      }
    end
    
    def toggle
      @todo.toggle!
      
      render json: {
        success: true,
        todo: serialize_todo(@todo)
      }
    end
    
    def reorder
      new_position = params[:position].to_i
      @todo.move_to(new_position)
      
      render json: {
        success: true,
        todo: serialize_todo(@todo)
      }
    end
    
    private
    
    def find_todo
      @todo = UserTodo.find_by!(id: params[:id], user_id: current_user.id)
    rescue ActiveRecord::RecordNotFound
      render json: { success: false, error: "Not found" }, status: 404
    end
    
    def todo_params
      params.require(:todo).permit(:title, :description, :list_type, :due_date, :priority, :image_url)
    end
    
    def serialize_todo(todo)
      {
        id: todo.id,
        title: todo.title,
        description: todo.description,
        image_url: todo.image_url,
        completed: todo.completed,
        position: todo.position,
        list_type: todo.list_type,
        due_date: todo.due_date,
        priority: todo.priority,
        created_at: todo.created_at,
        updated_at: todo.updated_at
      }
    end
    def ensure_todo_enabled
      return if SiteSetting.custom_plugin_enabled && SiteSetting.todo_enabled

      raise Discourse::NotFound
    end

  end
end
