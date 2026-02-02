import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class CustomPluginTabs extends Component {
  @service router;
  @service currentUser;
  
  @tracked activeTab = "checkin";
  
  get isOwnProfile() {
    return this.currentUser?.id === this.args.model?.id;
  }
  
  @action
  setTab(tab) {
    this.activeTab = tab;
  }
  
  <template>
    {{#if this.isOwnProfile}}
      <div class="custom-plugin-tabs">
        <div class="tabs-nav">
          <button 
            class="tab {{if (eq this.activeTab 'checkin') 'active'}}"
            {{on "click" (fn this.setTab "checkin")}}
          >
            📅 每日签到
          </button>
          <button 
            class="tab {{if (eq this.activeTab 'todo') 'active'}}"
            {{on "click" (fn this.setTab "todo")}}
          >
            ✅ 待办清单
          </button>
          <button 
            class="tab {{if (eq this.activeTab 'badges') 'active'}}"
            {{on "click" (fn this.setTab "badges")}}
          >
            🏅 徽章墙
          </button>
          <button 
            class="tab {{if (eq this.activeTab 'emoji') 'active'}}"
            {{on "click" (fn this.setTab "emoji")}}
          >
            😊 表情包
          </button>
        </div>
        
        <div class="tab-content">
          {{#if (eq this.activeTab "checkin")}}
            <CheckinPanel />
          {{else if (eq this.activeTab "todo")}}
            <TodoPanel />
          {{else if (eq this.activeTab "badges")}}
            <BadgeWall @userId={{this.currentUser.id}} />
          {{else if (eq this.activeTab "emoji")}}
            <CustomEmojiPanel />
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
