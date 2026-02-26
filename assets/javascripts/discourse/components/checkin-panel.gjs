import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { or, not } from "truth-helpers";
import { on } from "@ember/modifier";
import { htmlSafe } from "@ember/template";
import i18n from "discourse-common/helpers/i18n";

const WHEEL_PRIZES = [
  { label: "10 pts", color: "#F97316" },
  { label: "20 pts", color: "#FEF3C7" },
  { label: "50 pts", color: "#F97316" },
  { label: "Lucky!", color: "#FEF3C7" },
  { label: "5 pts",  color: "#F97316" },
  { label: "30 pts", color: "#FEF3C7" },
  { label: "100 pts",color: "#F97316" },
  { label: "Bonus",  color: "#FEF3C7" },
];

export default class CheckinPanel extends Component {
  @tracked isLoading = true;
  @tracked checkedInToday = false;
  @tracked consecutiveDays = 0;
  @tracked todayCheckin = null;
  @tracked stats = {};
  @tracked isCheckinLoading = false;

  @tracked canDraw = false;
  @tracked todayPrize = null;
  @tracked isDrawing = false;
  @tracked showPrizeModal = false;
  @tracked wonPrize = null;

  @tracked wheelAngle = 0;
  @tracked isSpinning = false;

  @tracked canBuyDraw = false;
  @tracked extraDrawCost = 50;
  @tracked extraDrawsRemaining = 0;
  @tracked userPoints = 0;

  @tracked calendarDates = [];
  @tracked showCalendar = false;

  @tracked showConfetti = false;

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
      this.calendarDates = result.stats?.this_month_dates || [];

      const lottery = await ajax("/custom-plugin/checkin/lottery");
      this.canDraw = lottery.can_draw;
      this.todayPrize = lottery.today_prize;
      this.canBuyDraw = lottery.can_buy_draw;
      this.extraDrawCost = lottery.extra_draw_cost || 50;
      this.extraDrawsRemaining = lottery.extra_draws_remaining || 0;
      this.userPoints = lottery.user_points || 0;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }

  get wheelStyle() {
    const transition = this.isSpinning
      ? "transform 4s cubic-bezier(0.17, 0.67, 0.12, 0.99)"
      : "none";
    return htmlSafe(`transform: rotate(${this.wheelAngle}deg); transition: ${transition};`);
  }

  @action
  async doCheckin() {
    if (this.isCheckinLoading || this.checkedInToday) return;
    this.isCheckinLoading = true;
    try {
      const result = await ajax("/custom-plugin/checkin", { type: "POST" });
      if (result.success) {
        this.checkedInToday = true;
        this.consecutiveDays = result.consecutive_days;
        this.todayCheckin = result.checkin;
        this.canDraw = true;
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
    this._spinWheel(() => this._finishLottery());
  }

  @action
  async doExtraLottery() {
    if (this.isDrawing || !this.canBuyDraw) return;
    this.isDrawing = true;
    this._spinWheel(() => this._finishExtraLottery());
  }

  _spinWheel(callback) {
    const extraRotations = 1800 + Math.random() * 1080;
    this.wheelAngle += extraRotations;
    this.isSpinning = true;
    setTimeout(() => {
      this.isSpinning = false;
      callback();
    }, 4200);
  }

  async _finishLottery() {
    try {
      const result = await ajax("/custom-plugin/checkin/draw", { type: "POST" });
      if (result.success) {
        this.wonPrize = result.prize;
        this.todayPrize = result.prize;
        this.canDraw = false;
        this.showConfetti = true;
        setTimeout(() => { this.showPrizeModal = true; }, 300);
        setTimeout(() => { this.showConfetti = false; }, 3000);
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isDrawing = false;
    }
  }

  async _finishExtraLottery() {
    try {
      const result = await ajax("/custom-plugin/checkin/extra-draw", { type: "POST" });
      if (result.success) {
        this.wonPrize = result.prize;
        this.userPoints = result.remaining_points;
        this.extraDrawsRemaining = result.extra_draws_remaining;
        this.canBuyDraw = this.extraDrawsRemaining > 0 && this.userPoints >= this.extraDrawCost;
        this.showConfetti = true;
        setTimeout(() => { this.showPrizeModal = true; }, 300);
        setTimeout(() => { this.showConfetti = false; }, 3000);
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isDrawing = false;
    }
  }

  @action toggleCalendar() { this.showCalendar = !this.showCalendar; }
  @action closePrizeModal() { this.showPrizeModal = false; }
  @action stopPropagation(event) { event.stopPropagation(); }

  get calendarData() {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth();
    const firstDay = new Date(year, month, 1).getDay();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const today = now.getDate();
    const checkedDates = new Set(this.calendarDates.map(d => new Date(d).getDate()));

    const cells = [];
    for (let i = 0; i < firstDay; i++) {
      cells.push({ day: "", checked: false, today: false, empty: true });
    }
    for (let d = 1; d <= daysInMonth; d++) {
      cells.push({ day: d, checked: checkedDates.has(d), today: d === today, empty: false });
    }
    return cells;
  }

  get calendarMonthLabel() {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
  }

  <template>
    <div class="checkin-panel">
      {{#if this.isLoading}}
        <div class="loading-spinner">{{i18n "custom_plugin.loading"}}</div>
      {{else}}
        <div class="checkin-header">
          <h3>{{i18n "custom_plugin.checkin.title"}}</h3>
          {{#if this.consecutiveDays}}
            <span class="consecutive-badge">
              {{i18n "custom_plugin.checkin.streak" days=this.consecutiveDays}}
            </span>
          {{/if}}
        </div>

        <button
          class="checkin-button {{if this.checkedInToday 'checked-in' 'can-checkin'}}"
          disabled={{this.checkedInToday}}
          {{on "click" this.doCheckin}}
        >
          {{#if this.isCheckinLoading}}
            {{i18n "custom_plugin.checkin.checking_in"}}
          {{else if this.checkedInToday}}
            {{i18n "custom_plugin.checkin.checked_in"}} {{i18n "custom_plugin.checkin.points_earned" points=this.todayCheckin.points_earned}}
          {{else}}
            {{i18n "custom_plugin.checkin.button"}}
          {{/if}}
        </button>

        <div class="checkin-stats">
          <div class="stat-item">
            <div class="stat-value">{{this.stats.total_checkins}}</div>
            <div class="stat-label">{{i18n "custom_plugin.checkin.stat_total"}}</div>
          </div>
          <div class="stat-item">
            <div class="stat-value">{{this.stats.total_points}}</div>
            <div class="stat-label">{{i18n "custom_plugin.checkin.stat_points"}}</div>
          </div>
          <div class="stat-item">
            <div class="stat-value">{{this.stats.this_month}}</div>
            <div class="stat-label">{{i18n "custom_plugin.checkin.stat_month"}}</div>
          </div>
        </div>

        <div class="checkin-calendar">
          <div class="calendar-header">
            <span class="month-title">{{this.calendarMonthLabel}}</span>
            <button class="calendar-toggle" {{on "click" this.toggleCalendar}}>
              {{if this.showCalendar (i18n "custom_plugin.checkin.calendar.hide") (i18n "custom_plugin.checkin.calendar.show")}}
            </button>
          </div>
          {{#if this.showCalendar}}
            <div class="calendar-weekdays">
              <span>Su</span><span>Mo</span><span>Tu</span><span>We</span><span>Th</span><span>Fr</span><span>Sa</span>
            </div>
            <div class="calendar-grid">
              {{#each this.calendarData as |cell|}}
                <div class="day-cell {{if cell.checked 'checked'}} {{if cell.today 'today'}} {{if cell.empty 'empty'}}">
                  {{cell.day}}
                </div>
              {{/each}}
            </div>
          {{/if}}
        </div>

        {{#if this.checkedInToday}}
          <div class="lottery-panel">
            <div class="lottery-header">
              <h4>{{i18n "custom_plugin.checkin.lottery.title"}}</h4>
              <p>{{i18n "custom_plugin.checkin.lottery.description"}}</p>
            </div>

            {{! ===== 转盘抽奖 ===== }}
            <div class="wheel-wrapper">
              <div class="wheel-pointer">
                <svg viewBox="0 0 40 50" width="30" height="38">
                  <polygon points="20,50 0,0 40,0" fill="#E11D48" stroke="#fff" stroke-width="2"/>
                  <circle cx="20" cy="12" r="6" fill="#fff"/>
                </svg>
              </div>
              <div class="wheel-outer">
                <div class="wheel-face" style={{this.wheelStyle}}>
                  <svg viewBox="0 0 300 300" class="wheel-svg">
                    <circle cx="150" cy="150" r="148" fill="#1a1a2e" stroke="#FFD700" stroke-width="4"/>
                    <g>
                      <path d="M150,150 L150,2 A148,148 0 0,1 254.7,45.3 Z" fill="#F97316"/>
                      <path d="M150,150 L254.7,45.3 A148,148 0 0,1 298,150 Z" fill="#FEF3C7"/>
                      <path d="M150,150 L298,150 A148,148 0 0,1 254.7,254.7 Z" fill="#F97316"/>
                      <path d="M150,150 L254.7,254.7 A148,148 0 0,1 150,298 Z" fill="#FEF3C7"/>
                      <path d="M150,150 L150,298 A148,148 0 0,1 45.3,254.7 Z" fill="#F97316"/>
                      <path d="M150,150 L45.3,254.7 A148,148 0 0,1 2,150 Z" fill="#FEF3C7"/>
                      <path d="M150,150 L2,150 A148,148 0 0,1 45.3,45.3 Z" fill="#F97316"/>
                      <path d="M150,150 L45.3,45.3 A148,148 0 0,1 150,2 Z" fill="#FEF3C7"/>
                    </g>
                    <g font-size="13" font-weight="bold" text-anchor="middle" dominant-baseline="middle">
                      <text transform="rotate(-67.5,150,150) translate(150,40)" fill="#fff">10 pts</text>
                      <text transform="rotate(-22.5,150,150) translate(150,40)" fill="#92400E">20 pts</text>
                      <text transform="rotate(22.5,150,150) translate(150,40)" fill="#fff">50 pts</text>
                      <text transform="rotate(67.5,150,150) translate(150,40)" fill="#92400E">Lucky!</text>
                      <text transform="rotate(112.5,150,150) translate(150,40)" fill="#fff">5 pts</text>
                      <text transform="rotate(157.5,150,150) translate(150,40)" fill="#92400E">30 pts</text>
                      <text transform="rotate(202.5,150,150) translate(150,40)" fill="#fff">100 pts</text>
                      <text transform="rotate(247.5,150,150) translate(150,40)" fill="#92400E">Bonus</text>
                    </g>
                    <circle cx="150" cy="150" r="25" fill="#FFD700" stroke="#fff" stroke-width="3"/>
                    <text x="150" y="153" text-anchor="middle" font-size="11" font-weight="bold" fill="#1a1a2e">GO</text>
                  </svg>
                </div>
              </div>
            </div>

            <button
              class="lottery-button"
              disabled={{or (not this.canDraw) this.isDrawing}}
              {{on "click" this.doLottery}}
            >
              {{#if this.isDrawing}}
                {{i18n "custom_plugin.checkin.lottery.drawing"}}
              {{else if this.todayPrize}}
                {{i18n "custom_plugin.checkin.lottery.won" prize=this.todayPrize}}
              {{else if this.canDraw}}
                {{i18n "custom_plugin.checkin.lottery.button"}}
              {{else}}
                {{i18n "custom_plugin.checkin.lottery.no_chance"}}
              {{/if}}
            </button>

            {{#if this.canBuyDraw}}
              <div class="extra-lottery-section">
                <p class="extra-lottery-info">
                  {{i18n "custom_plugin.checkin.lottery.extra_info" cost=this.extraDrawCost remaining=this.extraDrawsRemaining}}
                </p>
                <button
                  class="lottery-button extra-lottery-btn"
                  disabled={{this.isDrawing}}
                  {{on "click" this.doExtraLottery}}
                >
                  {{#if this.isDrawing}}
                    {{i18n "custom_plugin.checkin.lottery.drawing"}}
                  {{else}}
                    {{i18n "custom_plugin.checkin.lottery.extra_draw" cost=this.extraDrawCost}}
                  {{/if}}
                </button>
              </div>
            {{/if}}
          </div>
        {{/if}}
      {{/if}}

      {{! ===== 中奖弹窗 ===== }}
      {{#if this.showPrizeModal}}
        <div class="prize-modal-overlay" {{on "click" this.closePrizeModal}}>
          <div class="prize-modal" {{on "click" this.stopPropagation}}>
            <div class="prize-modal-sparkles">
              <span></span><span></span><span></span><span></span><span></span><span></span>
            </div>
            <h3>{{i18n "custom_plugin.checkin.lottery.congratulations"}}</h3>
            <div class="prize-display">{{this.wonPrize}}</div>
            <button class="prize-modal-btn" {{on "click" this.closePrizeModal}}>{{i18n "custom_plugin.checkin.lottery.ok"}}</button>
          </div>
        </div>
      {{/if}}

      {{! ===== 彩纸效果 ===== }}
      {{#if this.showConfetti}}
        <div class="confetti-container">
          <div class="confetti c1"></div>
          <div class="confetti c2"></div>
          <div class="confetti c3"></div>
          <div class="confetti c4"></div>
          <div class="confetti c5"></div>
          <div class="confetti c6"></div>
          <div class="confetti c7"></div>
          <div class="confetti c8"></div>
          <div class="confetti c9"></div>
          <div class="confetti c10"></div>
          <div class="confetti c11"></div>
          <div class="confetti c12"></div>
        </div>
      {{/if}}
    </div>
  </template>
}
