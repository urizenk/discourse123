import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "truth-helpers";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";

export default class TodoPanel extends Component {
  @tracked isLoading = true;
  @tracked todos = [];
  @tracked activeTab = "todo"; // todo 或 wish
  @tracked newTodoTitle = "";
  @tracked stats = {};
  
  constructor() {
    super(...arguments);
    this.loadTodos();
  }
  
  async loadTodos() {
    try {
      const result = await ajax(`/custom-plugin/todos?type=${this.activeTab}`);
      this.todos = result.todos;
      this.stats = result.stats;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }
  
  @action
  async switchTab(tab) {
    this.activeTab = tab;
    this.isLoading = true;
    await this.loadTodos();
  }
  
  @action
  async addTodo() {
    if (!this.newTodoTitle.trim()) return;
    
    try {
      const result = await ajax("/custom-plugin/todos", {
        type: "POST",
        data: {
          todo: {
            title: this.newTodoTitle,
            list_type: this.activeTab
          }
        }
      });
      
      if (result.success) {
        this.todos = [result.todo, ...this.todos];
        this.newTodoTitle = "";
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }
  
  @action
  async toggleTodo(todo) {
    try {
      const result = await ajax(`/custom-plugin/todos/${todo.id}/toggle`, {
        type: "PUT"
      });
      
      if (result.success) {
        const index = this.todos.findIndex(t => t.id === todo.id);
        if (index > -1) {
          this.todos = [
            ...this.todos.slice(0, index),
            result.todo,
            ...this.todos.slice(index + 1)
          ];
        }
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }
  
  @action
  async deleteTodo(todo) {
    if (!confirm("确定删除这个待办事项吗？")) return;
    
    try {
      await ajax(`/custom-plugin/todos/${todo.id}`, {
        type: "DELETE"
      });
      
      this.todos = this.todos.filter(t => t.id !== todo.id);
    } catch (error) {
      popupAjaxError(error);
    }
  }
  
  @action
  updateNewTodoTitle(event) {
    this.newTodoTitle = event.target.value;
  }
  
  @action
  handleKeydown(event) {
    if (event.key === "Enter") {
      this.addTodo();
    }
  }
  
  <template>
    <div class="todo-panel">
      <div class="todo-tabs">
        <button 
          class="tab {{if (eq this.activeTab 'todo') 'active'}}"
          {{on "click" (fn this.switchTab "todo")}}
        >
          To Do List
        </button>
        <button 
          class="tab {{if (eq this.activeTab 'wish') 'active'}}"
          {{on "click" (fn this.switchTab "wish")}}
        >
          Wish List
        </button>
      </div>
      
      <div class="todo-input">
        <input 
          type="text"
          placeholder="Add new item..."
          value={{this.newTodoTitle}}
          {{on "input" this.updateNewTodoTitle}}
          {{on "keydown" this.handleKeydown}}
        />
        <button {{on "click" this.addTodo}}>Add</button>
      </div>
      
      {{#if this.isLoading}}
        <div class="loading-spinner">Loading...</div>
      {{else if this.todos.length}}
        <div class="todo-list">
          {{#each this.todos as |todo|}}
            <div class="todo-item {{if todo.completed 'completed'}}">
              <div 
                class="todo-checkbox {{if todo.completed 'checked'}}"
                {{on "click" (fn this.toggleTodo todo)}}
              >
                {{#if todo.completed}}
                  <svg viewBox="0 0 24 24" width="14" height="14">
                    <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/>
                  </svg>
                {{/if}}
              </div>
              
              <span class="todo-title">{{todo.title}}</span>
              
              {{#if todo.priority}}
                <span class="priority-badge priority-{{todo.priority}}">
                  {{#if (eq todo.priority 1)}}Important{{/if}}
                  {{#if (eq todo.priority 2)}}Urgent{{/if}}
                </span>
              {{/if}}
              
              <div class="todo-actions">
                <button {{on "click" (fn this.deleteTodo todo)}} class="delete-btn">
                  <svg viewBox="0 0 24 24" width="16" height="16">
                    <path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/>
                  </svg>
                </button>
              </div>
            </div>
          {{/each}}
        </div>
      {{else}}
        <div class="todo-empty">
          <svg viewBox="0 0 24 24">
            <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-7 14l-5-5 1.41-1.41L12 14.17l7.59-7.59L21 8l-9 9z"/>
          </svg>
          <p>No items yet</p>
        </div>
      {{/if}}
    </div>
  </template>
}
