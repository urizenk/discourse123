import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import i18n from "discourse-common/helpers/i18n";

export default class UserCardBadges extends Component {
  @tracked isLoading = true;
  @tracked badges = [];
  @tracked todos = [];
  @tracked collections = [];

  get userId() { return this.args.outletArgs?.user?.id; }
  get username() { return this.args.outletArgs?.user?.username; }

  constructor() {
    super(...arguments);
    if (this.userId) this.loadData();
  }

  async loadData() {
    try {
      const badgeResult = await ajax(`/custom-plugin/badge-wall?user_id=${this.userId}`);
      this.badges = (badgeResult.collections || []).slice(0, 6).map(c => c.badge);

      const todoResult = await ajax(`/custom-plugin/todos?user_id=${this.userId}&type=todo`);
      this.todos = (todoResult.todos || []).slice(0, 3);

      const collResult = await ajax(`/custom-plugin/todos?user_id=${this.userId}&type=wish`);
      this.collections = (collResult.todos || []).slice(0, 3);
    } catch {
      // silently fail
    } finally {
      this.isLoading = false;
    }
  }

  @action
  goToProfile(tab) {
    if (this.username) {
      window.location.href = `/u/${this.username}/activity`;
    }
  }

  <template>
    {{#if this.userId}}
      <div class="user-card-custom-section">
        {{#if this.isLoading}}
          <div class="loading-text">{{i18n "custom_plugin.loading"}}</div>
        {{else}}
          <div class="user-card-quick-links">
            <button
              class="user-card-link-btn"
              type="button"
              title={{i18n "custom_plugin.user_card.collection"}}
              {{on "click" (fn this.goToProfile "collection")}}
            >
              <img src="/plugins/discourse-custom-plugin/images/icon-collection.png" alt="" class="link-icon" />
              <span>{{i18n "custom_plugin.user_card.collection"}}</span>
              {{#if this.collections.length}}
                <span class="link-count">{{this.collections.length}}</span>
              {{/if}}
            </button>
            <button
              class="user-card-link-btn"
              type="button"
              title={{i18n "custom_plugin.user_card.todo_list"}}
              {{on "click" (fn this.goToProfile "todo")}}
            >
              <img src="/plugins/discourse-custom-plugin/images/icon-todo.png" alt="" class="link-icon" />
              <span>{{i18n "custom_plugin.user_card.todo_list"}}</span>
              {{#if this.todos.length}}
                <span class="link-count">{{this.todos.length}}</span>
              {{/if}}
            </button>
          </div>

          {{#if this.badges.length}}
            <div class="user-card-badges">
              <h4>{{i18n "custom_plugin.user_card.badge_wall"}}</h4>
              <div class="badge-mini-grid">
                {{#each this.badges as |badge|}}
                  <div class="badge-mini" title={{badge.name}}>
                    {{#if badge.image_url}}
                      <img src={{badge.image_url}} alt={{badge.name}} />
                    {{else}}
                      <svg viewBox="0 0 24 24" width="24" height="24">
                        <path fill="#228B22" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
                      </svg>
                    {{/if}}
                  </div>
                {{/each}}
              </div>
            </div>
          {{/if}}
        {{/if}}
      </div>
    {{/if}}
  </template>
}
