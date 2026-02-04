import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { or, not } from "truth-helpers";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";

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
  
  // 老虎机动画状态
  @tracked showSlotMachine = false;
  @tracked slot1 = "?";
  @tracked slot2 = "?";
  @tracked slot3 = "?";
  @tracked slotAnimating = false;
  
  // 奖品配置
  prizes = [
    { symbol: "7", name: "7", weight: 5 },
    { symbol: "★", name: "Star", weight: 10 },
    { symbol: "♦", name: "Diamond", weight: 15 },
    { symbol: "♣", name: "Club", weight: 20 },
    { symbol: "♥", name: "Heart", weight: 25 },
    { symbol: "♠", name: "Spade", weight: 25 }
  ];
  
  slotSymbols = ["7", "★", "♦", "♣", "♥", "♠"];
  
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
    this.showSlotMachine = true;
    this.slotAnimating = true;
    
    // 开始老虎机动画
    let animationCount = 0;
    const maxAnimations = 20;
    
    const animateSlots = () => {
      this.slot1 = this.slotSymbols[Math.floor(Math.random() * this.slotSymbols.length)];
      this.slot2 = this.slotSymbols[Math.floor(Math.random() * this.slotSymbols.length)];
      this.slot3 = this.slotSymbols[Math.floor(Math.random() * this.slotSymbols.length)];
      
      animationCount++;
      
      if (animationCount < maxAnimations) {
        setTimeout(animateSlots, 100 + animationCount * 10);
      } else {
        this.finishLottery();
      }
    };
    
    animateSlots();
  }
  
  async finishLottery() {
    try {
      const result = await ajax("/custom-plugin/checkin/draw", {
        type: "POST"
      });
      
      if (result.success) {
        // 显示最终结果
        const prizeSymbol = this.getPrizeSymbol(result.prize);
        this.slot1 = prizeSymbol;
        this.slot2 = prizeSymbol;
        this.slot3 = prizeSymbol;
        
        this.wonPrize = result.prize;
        this.todayPrize = result.prize;
        this.canDraw = false;
        
        // 延迟显示结果弹窗
        setTimeout(() => {
          this.slotAnimating = false;
          this.showPrizeModal = true;
        }, 500);
      }
    } catch (error) {
      popupAjaxError(error);
      this.slotAnimating = false;
    } finally {
      this.isDrawing = false;
    }
  }
  
  getPrizeSymbol(prizeName) {
    // 根据奖品返回对应符号
    if (prizeName && prizeName.includes("积分")) return "★";
    if (prizeName && prizeName.includes("大奖")) return "7";
    return this.slotSymbols[Math.floor(Math.random() * this.slotSymbols.length)];
  }
  
  @action
  closePrizeModal() {
    this.showPrizeModal = false;
  }
  
  @action
  stopPropagation(event) {
    event.stopPropagation();
  }
  
  <template>
    <div class="checkin-panel">
      {{#if this.isLoading}}
        <div class="loading-spinner">Loading...</div>
      {{else}}
        <div class="checkin-header">
          <h3>Daily Check-in</h3>
          {{#if this.consecutiveDays}}
            <span class="consecutive-badge">
              {{this.consecutiveDays}} days streak
            </span>
          {{/if}}
        </div>
        
        <button 
          class="checkin-button {{if this.checkedInToday 'checked-in' 'can-checkin'}}"
          disabled={{this.checkedInToday}}
          {{on "click" this.doCheckin}}
        >
          {{#if this.isCheckinLoading}}
            Checking in...
          {{else if this.checkedInToday}}
            Checked in (+{{this.todayCheckin.points_earned}} points)
          {{else}}
            Check In Now
          {{/if}}
        </button>
        
        <div class="checkin-stats">
          <div class="stat-item">
            <div class="stat-value">{{this.stats.total_checkins}}</div>
            <div class="stat-label">Total Check-ins</div>
          </div>
          <div class="stat-item">
            <div class="stat-value">{{this.stats.total_points}}</div>
            <div class="stat-label">Total Points</div>
          </div>
          <div class="stat-item">
            <div class="stat-value">{{this.stats.this_month}}</div>
            <div class="stat-label">This Month</div>
          </div>
        </div>
        
        {{#if this.checkedInToday}}
          <div class="lottery-panel">
            <div class="lottery-header">
              <h4>Lucky Draw</h4>
              <p>You got a chance to draw!</p>
            </div>
            
            {{#if this.showSlotMachine}}
              <div class="slot-machine {{if this.slotAnimating 'animating'}}">
                <div class="slot-container">
                  <div class="slot-reel">
                    <span class="slot-symbol">{{this.slot1}}</span>
                  </div>
                  <div class="slot-reel">
                    <span class="slot-symbol">{{this.slot2}}</span>
                  </div>
                  <div class="slot-reel">
                    <span class="slot-symbol">{{this.slot3}}</span>
                  </div>
                </div>
              </div>
            {{/if}}
            
            <button 
              class="lottery-button"
              disabled={{or (not this.canDraw) this.isDrawing}}
              {{on "click" this.doLottery}}
            >
              {{#if this.isDrawing}}
                Drawing...
              {{else if this.todayPrize}}
                Won: {{this.todayPrize}}
              {{else if this.canDraw}}
                Draw Now
              {{else}}
                No chance available
              {{/if}}
            </button>
          </div>
        {{/if}}
      {{/if}}
      
      {{#if this.showPrizeModal}}
        <div class="prize-modal-overlay" {{on "click" this.closePrizeModal}}>
          <div class="prize-modal" {{on "click" this.stopPropagation}}>
            <h3>Congratulations!</h3>
            <div class="prize-display">{{this.wonPrize}}</div>
            <button {{on "click" this.closePrizeModal}}>OK</button>
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
