import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "truth-helpers";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";

export default class TodoPanel extends Component {
  @tracked isLoading = true;
  @tracked todos = [];
  @tracked activeTab = "todo";
  @tracked newTodoTitle = "";
  @tracked newTodoImageUrl = "";
  @tracked isUploading = false;
  @tracked stats = {};

  get isOwner() { return this.args.isOwner !== false; }
  get userId() { return this.args.userId; }

  constructor() {
    super(...arguments);
    this.loadTodos();
  }

  async loadTodos() {
    try {
      let url = `/custom-plugin/todos?type=${this.activeTab}`;
      if (this.userId) url += `&user_id=${this.userId}`;
      const result = await ajax(url);
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
  triggerImageUpload() {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = "image/*";
    input.onchange = (e) => this.handleImageSelect(e);
    input.click();
  }

  @action
  async handleImageSelect(event) {
    const file = event.target.files[0];
    if (!file) return;
    this.isUploading = true;
    try {
      const formData = new FormData();
      formData.append("file", file);
      formData.append("type", "composer");
      const uploadResult = await ajax("/uploads.json", {
        type: "POST", data: formData, processData: false, contentType: false
      });
      this.newTodoImageUrl = uploadResult.url;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isUploading = false;
    }
  }

  @action removeImage() { this.newTodoImageUrl = ""; }

  @action
  async addTodo() {
    if (!this.newTodoTitle.trim()) return;
    try {
      const todoData = { title: this.newTodoTitle, list_type: this.activeTab };
      if (this.newTodoImageUrl) todoData.image_url = this.newTodoImageUrl;
      const result = await ajax("/custom-plugin/todos", {
        type: "POST", data: { todo: todoData }
      });
      if (result.success) {
        this.todos = [result.todo, ...this.todos];
        this.newTodoTitle = "";
        this.newTodoImageUrl = "";
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async toggleTodo(todo) {
    try {
      const result = await ajax(`/custom-plugin/todos/${todo.id}/toggle`, { type: "PUT" });
      if (result.success) {
        const idx = this.todos.findIndex(t => t.id === todo.id);
        if (idx > -1) {
          this.todos = [...this.todos.slice(0, idx), result.todo, ...this.todos.slice(idx + 1)];
        }
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async deleteTodo(todo) {
    if (!confirm(I18n.t("js.custom_plugin.todo.delete_confirm"))) return;
    try {
      await ajax(`/custom-plugin/todos/${todo.id}`, { type: "DELETE" });
      this.todos = this.todos.filter(t => t.id !== todo.id);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action updateNewTodoTitle(event) { this.newTodoTitle = event.target.value; }
  @action handleKeydown(event) { if (event.key === "Enter") this.addTodo(); }

  <template>
    <div class="todo-panel">
      <div class="todo-tabs">
        <button
          class="tab {{if (eq this.activeTab 'todo') 'active'}}"
          {{on "click" (fn this.switchTab "todo")}}
        >{{i18n "custom_plugin.todo.tabs.todo"}}</button>
        <button
          class="tab {{if (eq this.activeTab 'wish') 'active'}}"
          {{on "click" (fn this.switchTab "wish")}}
        >{{i18n "custom_plugin.todo.tabs.wish"}}</button>
      </div>

      {{#if this.isOwner}}
        <div class="todo-input-wrapper">
          <div class="todo-input">
            <input
              type="text"
              placeholder={{i18n "custom_plugin.todo.add_placeholder"}}
              value={{this.newTodoTitle}}
              {{on "input" this.updateNewTodoTitle}}
              {{on "keydown" this.handleKeydown}}
            />
            <button
              class="upload-btn"
              title={{i18n "custom_plugin.todo.add_image"}}
              {{on "click" this.triggerImageUpload}}
            >
              {{#if this.isUploading}}
                ...
              {{else}}
                <svg viewBox="0 0 24 24" width="18" height="18">
                  <path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/>
                </svg>
              {{/if}}
            </button>
            <button {{on "click" this.addTodo}}>{{i18n "custom_plugin.add"}}</button>
          </div>
          {{#if this.newTodoImageUrl}}
            <div class="todo-image-preview">
              <img src={{this.newTodoImageUrl}} alt="Preview" />
              <button class="remove-image" {{on "click" this.removeImage}}>×</button>
            </div>
          {{/if}}
        </div>
      {{/if}}

      {{#if this.isLoading}}
        <div class="loading-spinner">{{i18n "custom_plugin.loading"}}</div>
      {{else if this.todos.length}}
        <div class="todo-list">
          {{#each this.todos as |todo|}}
            <div class="todo-item {{if todo.completed 'completed'}} {{if todo.image_url 'has-image'}}">
              <div class="todo-main">
                {{#if this.isOwner}}
                  <div
                    class="todo-checkbox {{if todo.completed 'checked'}}"
                    role="button"
                    {{on "click" (fn this.toggleTodo todo)}}
                  >
                    {{#if todo.completed}}
                      <svg viewBox="0 0 24 24" width="14" height="14"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>
                    {{/if}}
                  </div>
                {{else}}
                  <div class="todo-checkbox readonly {{if todo.completed 'checked'}}">
                    {{#if todo.completed}}
                      <svg viewBox="0 0 24 24" width="14" height="14"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>
                    {{/if}}
                  </div>
                {{/if}}

                <span class="todo-title">{{todo.title}}</span>

                {{#if todo.priority}}
                  <span class="priority-badge priority-{{todo.priority}}">
                    {{#if (eq todo.priority 1)}}{{i18n "custom_plugin.todo.priority.important"}}{{/if}}
                    {{#if (eq todo.priority 2)}}{{i18n "custom_plugin.todo.priority.urgent"}}{{/if}}
                  </span>
                {{/if}}

                {{#if this.isOwner}}
                  <div class="todo-actions">
                    <button {{on "click" (fn this.deleteTodo todo)}} class="delete-btn">
                      <svg viewBox="0 0 24 24" width="16" height="16">
                        <path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/>
                      </svg>
                    </button>
                  </div>
                {{/if}}
              </div>
              {{#if todo.image_url}}
                <div class="todo-image">
                  <img src={{todo.image_url}} alt={{todo.title}} />
                </div>
              {{/if}}
            </div>
          {{/each}}
        </div>
      {{else}}
        <div class="todo-empty">
          <svg viewBox="0 0 24 24">
            <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-7 14l-5-5 1.41-1.41L12 14.17l7.59-7.59L21 8l-9 9z"/>
          </svg>
          <p>{{i18n "custom_plugin.todo.empty"}}</p>
        </div>
      {{/if}}
    </div>
  </template>
}
