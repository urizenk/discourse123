import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

export default class CustomEmojiPanel extends Component {
  @tracked isLoading = true;
  @tracked emojis = [];
  @tracked stats = {};
  @tracked isUploading = false;
  @tracked newEmojiName = "";
  
  constructor() {
    super(...arguments);
    this.loadEmojis();
  }
  
  async loadEmojis() {
    try {
      const result = await ajax("/custom-plugin/custom-emoji");
      this.emojis = result.emojis;
      this.stats = result.stats;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }
  
  @action
  triggerUpload() {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = "image/*";
    input.onchange = (e) => this.handleFileSelect(e);
    input.click();
  }
  
  @action
  async handleFileSelect(event) {
    const file = event.target.files[0];
    if (!file) return;
    
    // 检查文件大小
    const maxSize = 256 * 1024; // 256KB
    if (file.size > maxSize) {
      alert("文件大小超过限制");
      return;
    }
    
    // 生成表情名称
    const name = prompt("请输入表情名称（只能包含字母、数字和下划线）：");
    if (!name) return;
    
    this.isUploading = true;
    
    try {
      // 先上传文件
      const formData = new FormData();
      formData.append("file", file);
      formData.append("type", "custom_emoji");
      
      const uploadResult = await ajax("/uploads.json", {
        type: "POST",
        data: formData,
        processData: false,
        contentType: false
      });
      
      // 创建自定义表情
      const result = await ajax("/custom-plugin/custom-emoji", {
        type: "POST",
        data: {
          upload_id: uploadResult.id,
          name: name
        }
      });
      
      if (result.success) {
        this.emojis = [result.emoji, ...this.emojis];
        this.stats = {
          ...this.stats,
          count: this.stats.count + 1
        };
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isUploading = false;
    }
  }
  
  @action
  async deleteEmoji(emoji) {
    if (!confirm(I18n.t("custom_plugin.emoji.delete_confirm"))) return;
    
    try {
      await ajax(`/custom-plugin/custom-emoji/${emoji.id}`, {
        type: "DELETE"
      });
      
      this.emojis = this.emojis.filter(e => e.id !== emoji.id);
      this.stats = {
        ...this.stats,
        count: this.stats.count - 1
      };
    } catch (error) {
      popupAjaxError(error);
    }
  }
  
  <template>
    <div class="custom-emoji-panel">
      <div class="emoji-header">
        <h3>{{I18n.t "custom_plugin.emoji.title"}}</h3>
        <span class="emoji-count">{{this.stats.count}}/{{this.stats.max}}</span>
      </div>
      
      <div class="emoji-upload" role="button" {{on "click" this.triggerUpload}}>
        {{#if this.isUploading}}
          <p>上传中...</p>
        {{else}}
          <svg viewBox="0 0 24 24">
            <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
          </svg>
          <p>{{I18n.t "custom_plugin.emoji.drag_hint"}}</p>
          <p class="size-hint">最大 256KB</p>
        {{/if}}
      </div>
      
      {{#if this.isLoading}}
        <div class="loading-spinner">加载中...</div>
      {{else if this.emojis.length}}
        <div class="emoji-grid">
          {{#each this.emojis as |emoji|}}
            <div class="emoji-item">
              <img src={{emoji.url}} alt={{emoji.name}} />
              <div class="emoji-name">:{{emoji.name}}:</div>
              <button 
                class="emoji-delete"
                {{on "click" (fn this.deleteEmoji emoji)}}
              >
                ×
              </button>
            </div>
          {{/each}}
        </div>
      {{else}}
        <div class="todo-empty">
          <p>{{I18n.t "custom_plugin.emoji.empty"}}</p>
        </div>
      {{/if}}
    </div>
  </template>
}
