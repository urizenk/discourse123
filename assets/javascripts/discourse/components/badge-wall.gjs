import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "truth-helpers";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import i18n from "discourse-common/helpers/i18n";

export default class BadgeWall extends Component {
  @tracked isLoading = true;
  @tracked collections = [];
  @tracked earnedBadges = [];
  @tracked allBadges = [];
  @tracked stats = {};
  @tracked activeTab = "collected";

  get userId() { return this.args.userId; }

  constructor() {
    super(...arguments);
    this.loadBadges();
  }

  async loadBadges() {
    try {
      let url = "/custom-plugin/badge-wall";
      if (this.userId) url += `?user_id=${this.userId}`;
      const result = await ajax(url);
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
    return this.activeTab === "collected"
      ? this.collections.map(c => c.badge)
      : this.earnedBadges;
  }

  get progressPercentage() {
    if (!this.stats.total) return 0;
    return Math.round((this.stats.collected / this.stats.total) * 100);
  }

  get isOwner() {
    return !this.userId || this.userId === this.args.currentUserId;
  }

  @action switchTab(tab) { this.activeTab = tab; }

  @action
  async collectBadge(badge) {
    try {
      const result = await ajax(`/custom-plugin/badge-wall/collect/${badge.id}`, { type: "POST" });
      if (result.success) {
        const idx = this.earnedBadges.findIndex(b => b.id === badge.id);
        if (idx > -1) {
          this.earnedBadges = [
            ...this.earnedBadges.slice(0, idx),
            { ...this.earnedBadges[idx], collected: true },
            ...this.earnedBadges.slice(idx + 1)
          ];
        }
        this.collections = [...this.collections, result.collection];
        this.stats = { ...this.stats, collected: this.stats.collected + 1 };
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async uncollectBadge(badge) {
    try {
      const result = await ajax(`/custom-plugin/badge-wall/collect/${badge.id}`, { type: "DELETE" });
      if (result.success) {
        const idx = this.earnedBadges.findIndex(b => b.id === badge.id);
        if (idx > -1) {
          this.earnedBadges = [
            ...this.earnedBadges.slice(0, idx),
            { ...this.earnedBadges[idx], collected: false },
            ...this.earnedBadges.slice(idx + 1)
          ];
        }
        this.collections = this.collections.filter(c => c.badge.id !== badge.id);
        this.stats = { ...this.stats, collected: Math.max(0, this.stats.collected - 1) };
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="badge-wall">
      {{#if this.isLoading}}
        <div class="loading-spinner">{{i18n "custom_plugin.loading"}}</div>
      {{else}}
        <div class="badge-wall-header">
          <h2>{{i18n "custom_plugin.badge_wall.title"}}</h2>
          <div class="progress-info">
            <span>{{i18n "custom_plugin.badge_wall.progress"}}: {{this.stats.collected}}/{{this.stats.total}}</span>
            <div class="progress-bar">
              <div class="progress" style="width: {{this.progressPercentage}}%"></div>
            </div>
          </div>
        </div>

        <div class="todo-tabs" style="margin-bottom: 20px;">
          <button
            class="tab {{if (eq this.activeTab 'collected') 'active'}}"
            {{on "click" (fn this.switchTab "collected")}}
          >{{i18n "custom_plugin.badge_wall.collected"}} ({{this.stats.collected}})</button>
          <button
            class="tab {{if (eq this.activeTab 'earned') 'active'}}"
            {{on "click" (fn this.switchTab "earned")}}
          >{{i18n "custom_plugin.badge_wall.earned"}} ({{this.stats.earned}})</button>
        </div>

        {{#if this.displayBadges.length}}
          <div class="badge-grid">
            {{#each this.displayBadges as |badge|}}
              <div class="badge-card {{if badge.earned 'earned' 'not-earned'}} {{if badge.collected 'collected'}}">
                <div class="badge-icon">
                  {{#if badge.image_url}}
                    <img src={{badge.image_url}} alt={{badge.name}} />
                  {{else}}
                    <span class="badge-icon-placeholder">
                      <svg viewBox="0 0 24 24" width="32" height="32">
                        <path fill="#ccc" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
                      </svg>
                    </span>
                  {{/if}}
                </div>
                <div class="badge-name">{{badge.name}}</div>
                <div class="badge-status">
                  {{#if badge.collected}}
                    {{i18n "custom_plugin.badge_wall.collected"}}
                  {{else if badge.earned}}
                    {{i18n "custom_plugin.badge_wall.earned"}}
                  {{else}}
                    {{i18n "custom_plugin.badge_wall.not_earned"}}
                  {{/if}}
                </div>
                {{#if badge.earned}}
                  {{#if badge.collected}}
                    <button class="collect-button uncollect" {{on "click" (fn this.uncollectBadge badge)}}>
                      {{i18n "custom_plugin.badge_wall.uncollect"}}
                    </button>
                  {{else}}
                    <button class="collect-button" {{on "click" (fn this.collectBadge badge)}}>
                      {{i18n "custom_plugin.badge_wall.collect"}}
                    </button>
                  {{/if}}
                {{/if}}
              </div>
            {{/each}}
          </div>
        {{else}}
          <div class="todo-empty">
            <p>{{i18n "custom_plugin.badge_wall.empty"}}</p>
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
