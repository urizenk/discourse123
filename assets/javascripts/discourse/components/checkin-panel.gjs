import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

export default class CheckinPanel extends Component {
  @tracked isLoading = true;
  @tracked checkedInToday = false;
  @tracked consecutiveDays = 0;
  @tracked todayCheckin = null;
  @tracked stats = {};
  @tracked isCheckinLoading = false;
  
  // 抽奖相关
  @tracked canDraw = false;
  @tracked todayPrize = null;
  @tracked isDrawing = false;
  @tracked showPrizeModal = false;
  @tracked wonPrize = null;
  
  constructor() {
    super(...arguments);
    this.loadCheckinData();
  }
  
  async loadCheckinData() {
    try {
      const result = await ajax("/custom-plugin/checkin");
      this.checkedInToday = result.checked_in_today;
      this.consecutiveDays = result.consecutive_days;
      this.todayCheckin = result.today_checkin;
      this.stats = result.stats;
      
      // 加载抽奖状态
      const lottery = await ajax("/custom-plugin/checkin/lottery");
      this.canDraw = lottery.can_draw;
      this.todayPrize = lottery.today_prize;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }
  
  @action
  async doCheckin() {
    if (this.isCheckinLoading || this.checkedInToday) return;
    
    this.isCheckinLoading = true;
    
    try {
      const result = await ajax("/custom-plugin/checkin", {
        type: "POST"
      });
      
      if (result.success) {
        this.checkedInToday = true;
        this.consecutiveDays = result.consecutive_days;
        this.todayCheckin = result.checkin;
        this.canDraw = true;
        
        // 显示成功提示
        // 可以添加动画效果
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isCheckinLoading = false;
    }
  }
  
  @action
  async doLottery() {
    if (this.isDrawing || !this.canDraw) return;
    
    this.isDrawing = true;
    
    try {
      const result = await ajax("/custom-plugin/checkin/draw", {
        type: "POST"
      });
      
      if (result.success) {
        this.wonPrize = result.prize;
        this.todayPrize = result.prize;
        this.canDraw = false;
        this.showPrizeModal = true;
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isDrawing = false;
    }
  }
  
  @action
  closePrizeModal() {
    this.showPrizeModal = false;
  }
  
  <template>
    <div class="checkin-panel">
      {{#if this.isLoading}}
        <div class="loading-spinner">加载中...</div>
      {{else}}
        <div class="checkin-header">
          <h3>{{I18n.t "custom_plugin.checkin.title"}}</h3>
          {{#if this.consecutiveDays}}
            <span class="consecutive-badge">
              🔥 连续 {{this.consecutiveDays}} 天
            </span>
          {{/if}}
        </div>
        
        <button 
          class="checkin-button {{if this.checkedInToday 'checked-in' 'can-checkin'}}"
          disabled={{this.checkedInToday}}
          {{on "click" this.doCheckin}}
        >
          {{#if this.isCheckinLoading}}
            签到中...
          {{else if this.checkedInToday}}
            ✓ 今日已签到 (+{{this.todayCheckin.points_earned}}积分)
          {{else}}
            立即签到
          {{/if}}
        </button>
        
        <div class="checkin-stats">
          <div class="stat-item">
            <div class="stat-value">{{this.stats.total_checkins}}</div>
            <div class="stat-label">累计签到</div>
          </div>
          <div class="stat-item">
            <div class="stat-value">{{this.stats.total_points}}</div>
            <div class="stat-label">累计积分</div>
          </div>
          <div class="stat-item">
            <div class="stat-value">{{this.stats.this_month}}</div>
            <div class="stat-label">本月签到</div>
          </div>
        </div>
        
        {{#if this.checkedInToday}}
          <div class="lottery-panel">
            <div class="lottery-header">
              <h4>🎰 幸运抽奖</h4>
              <p>签到成功，获得一次抽奖机会！</p>
            </div>
            
            <button 
              class="lottery-button"
              disabled={{or (not this.canDraw) this.isDrawing}}
              {{on "click" this.doLottery}}
            >
              {{#if this.isDrawing}}
                抽奖中...
              {{else if this.todayPrize}}
                已抽奖: {{this.todayPrize}}
              {{else if this.canDraw}}
                立即抽奖
              {{else}}
                暂无抽奖机会
              {{/if}}
            </button>
          </div>
        {{/if}}
      {{/if}}
      
      {{#if this.showPrizeModal}}
        <div class="prize-modal-overlay" {{on "click" this.closePrizeModal}}>
          <div class="prize-modal" {{on "click" (fn (mut this) "stopPropagation")}}>
            <h3>🎉 恭喜中奖！</h3>
            <div class="prize-display">{{this.wonPrize}}</div>
            <button {{on "click" this.closePrizeModal}}>确定</button>
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
