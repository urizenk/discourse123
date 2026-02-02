import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

export default class BadgeWall extends Component {
  @tracked isLoading = true;
  @tracked collections = [];
  @tracked earnedBadges = [];
  @tracked allBadges = [];
  @tracked stats = {};
  @tracked activeTab = "collected"; // collected 或 all
  
  constructor() {
    super(...arguments);
    this.loadBadges();
  }
  
  async loadBadges() {
    try {
      const result = await ajax("/custom-plugin/badge-wall");
      this.collections = result.collections;
      this.earnedBadges = result.earned_badges;
      this.allBadges = result.all_badges;
      this.stats = result.stats;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }
  
  get displayBadges() {
    if (this.activeTab === "collected") {
      return this.collections.map(c => c.badge);
    }
    return this.earnedBadges;
  }
  
  get progressPercentage() {
    if (!this.stats.total) return 0;
    return Math.round((this.stats.collected / this.stats.total) * 100);
  }
  
  @action
  switchTab(tab) {
    this.activeTab = tab;
  }
  
  @action
  async collectBadge(badge) {
    try {
      const result = await ajax(`/custom-plugin/badge-wall/collect/${badge.id}`, {
        type: "POST"
      });
      
      if (result.success) {
        // 更新状态
        const index = this.earnedBadges.findIndex(b => b.id === badge.id);
        if (index > -1) {
          this.earnedBadges = [
            ...this.earnedBadges.slice(0, index),
            { ...this.earnedBadges[index], collected: true },
            ...this.earnedBadges.slice(index + 1)
          ];
        }
        
        this.collections = [...this.collections, result.collection];
        this.stats = {
          ...this.stats,
          collected: this.stats.collected + 1
        };
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }
  
  <template>
    <div class="badge-wall">
      {{#if this.isLoading}}
        <div class="loading-spinner">加载中...</div>
      {{else}}
        <div class="badge-wall-header">
          <h2>{{I18n.t "custom_plugin.badge_wall.title"}}</h2>
          <div class="progress-info">
            <span>收集进度: {{this.stats.collected}}/{{this.stats.total}}</span>
            <div class="progress-bar">
              <div class="progress" style="width: {{this.progressPercentage}}%"></div>
            </div>
          </div>
        </div>
        
        <div class="todo-tabs" style="margin-bottom: 20px;">
          <button 
            class="tab {{if (eq this.activeTab 'collected') 'active'}}"
            {{on "click" (fn this.switchTab "collected")}}
          >
            已收藏 ({{this.stats.collected}})
          </button>
          <button 
            class="tab {{if (eq this.activeTab 'earned') 'active'}}"
            {{on "click" (fn this.switchTab "earned")}}
          >
            已获得 ({{this.stats.earned}})
          </button>
        </div>
        
        {{#if this.displayBadges.length}}
          <div class="badge-grid">
            {{#each this.displayBadges as |badge|}}
              <div class="badge-card {{if badge.earned 'earned' 'not-earned'}} {{if badge.collected 'collected'}}">
                <div class="badge-icon">
                  {{#if badge.image_url}}
                    <img src={{badge.image_url}} alt={{badge.name}} />
                  {{else}}
                    <span class="badge-icon-placeholder">🏅</span>
                  {{/if}}
                </div>
                <div class="badge-name">{{badge.name}}</div>
                <div class="badge-status">
                  {{#if badge.collected}}
                    ✓ 已收藏
                  {{else if badge.earned}}
                    已获得
                  {{else}}
                    未获得
                  {{/if}}
                </div>
                {{#if (and badge.earned (not badge.collected))}}
                  <button 
                    class="collect-button"
                    {{on "click" (fn this.collectBadge badge)}}
                  >
                    收藏
                  </button>
                {{/if}}
              </div>
            {{/each}}
          </div>
        {{else}}
          <div class="todo-empty">
            <p>{{I18n.t "custom_plugin.badge_wall.empty"}}</p>
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
