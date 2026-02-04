import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { eq } from "truth-helpers";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import CheckinPanel from "../../components/checkin-panel";
import TodoPanel from "../../components/todo-panel";
import BadgeWall from "../../components/badge-wall";
import CustomEmojiPanel from "../../components/custom-emoji-panel";

export default class CustomPluginTabs extends Component {
  @service router;
  @service currentUser;
  
  @tracked activeTab = "badges";
  @tracked isCollapsed = false;
  
  get isOwnProfile() {
    return this.currentUser?.id === this.args.outletArgs?.model?.id;
  }
  
  get profileUserId() {
    return this.args.outletArgs?.model?.id;
  }
  
  @action
  setTab(tab) {
    this.activeTab = tab;
    this.isCollapsed = false;
  }
  
  @action
  toggleCollapse() {
    this.isCollapsed = !this.isCollapsed;
  }
  
  <template>
    <div class="custom-plugin-container secondary-position">
      <div class="custom-plugin-header" {{on "click" this.toggleCollapse}}>
        <h3>Personal Center</h3>
        <span class="collapse-icon">{{if this.isCollapsed "▶" "▼"}}</span>
      </div>
      
      {{#unless this.isCollapsed}}
        <div class="custom-plugin-tabs">
          <div class="tabs-nav">
            {{#if this.isOwnProfile}}
              <button 
                type="button"
                class="tab {{if (eq this.activeTab 'checkin') 'active'}}"
                {{on "click" (fn this.setTab "checkin")}}
              >
                Daily Check-in
              </button>
            {{/if}}
            <button 
              type="button"
              class="tab {{if (eq this.activeTab 'todo') 'active'}}"
              {{on "click" (fn this.setTab "todo")}}
            >
              To Do List
            </button>
            <button 
              type="button"
              class="tab {{if (eq this.activeTab 'badges') 'active'}}"
              {{on "click" (fn this.setTab "badges")}}
            >
              Badge Wall
            </button>
            {{#if this.isOwnProfile}}
              <button 
                type="button"
                class="tab {{if (eq this.activeTab 'emoji') 'active'}}"
                {{on "click" (fn this.setTab "emoji")}}
              >
                My Emoji
              </button>
            {{/if}}
          </div>
          
          <div class="tab-content">
            {{#if (eq this.activeTab "checkin")}}
              <CheckinPanel />
            {{else if (eq this.activeTab "todo")}}
              <TodoPanel @userId={{this.profileUserId}} @isOwner={{this.isOwnProfile}} />
            {{else if (eq this.activeTab "badges")}}
              <BadgeWall @userId={{this.profileUserId}} />
            {{else if (eq this.activeTab "emoji")}}
              <CustomEmojiPanel />
            {{/if}}
          </div>
        </div>
      {{/unless}}
    </div>
  </template>
}
