import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import i18n from "discourse-common/helpers/i18n";

export default class UserCardBadges extends Component {
  @tracked isLoading = true;
  @tracked badges = [];
  @tracked todos = [];

  get userId() { return this.args.outletArgs?.user?.id; }

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
    } catch {
      // silently fail for user card popup
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    {{#if this.userId}}
      <div class="user-card-custom-section">
        {{#if this.isLoading}}
          <div class="loading-text">{{i18n "custom_plugin.loading"}}</div>
        {{else}}
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

          {{#if this.todos.length}}
            <div class="user-card-todos">
              <h4>{{i18n "custom_plugin.user_card.todo_list"}}</h4>
              <ul class="todo-mini-list">
                {{#each this.todos as |todo|}}
                  <li class="{{if todo.completed 'completed'}}">
                    <span class="check-icon">{{if todo.completed "✓" "○"}}</span>
                    {{todo.title}}
                  </li>
                {{/each}}
              </ul>
            </div>
          {{/if}}
        {{/if}}
      </div>
    {{/if}}
  </template>
}
