import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { or, not } from "truth-helpers";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";

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

  @tracked showSlotMachine = false;
  @tracked slot1 = "?";
  @tracked slot2 = "?";
  @tracked slot3 = "?";
  @tracked slotAnimating = false;

  @tracked canBuyDraw = false;
  @tracked extraDrawCost = 50;
  @tracked extraDrawsRemaining = 0;
  @tracked userPoints = 0;

  @tracked calendarDates = [];
  @tracked showCalendar = false;

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
    this.showSlotMachine = true;
    this.slotAnimating = true;
    this._animateSlots(() => this._finishLottery());
  }

  @action
  async doExtraLottery() {
    if (this.isDrawing || !this.canBuyDraw) return;
    this.isDrawing = true;
    this.showSlotMachine = true;
    this.slotAnimating = true;
    this._animateSlots(() => this._finishExtraLottery());
  }

  _animateSlots(callback) {
    let count = 0;
    const animate = () => {
      this.slot1 = this.slotSymbols[Math.floor(Math.random() * 6)];
      this.slot2 = this.slotSymbols[Math.floor(Math.random() * 6)];
      this.slot3 = this.slotSymbols[Math.floor(Math.random() * 6)];
      count++;
      if (count < 20) {
        setTimeout(animate, 100 + count * 10);
      } else {
        callback();
      }
    };
    animate();
  }

  async _finishLottery() {
    try {
      const result = await ajax("/custom-plugin/checkin/draw", { type: "POST" });
      if (result.success) {
        this.slot1 = this.slot2 = this.slot3 = "★";
        this.wonPrize = result.prize;
        this.todayPrize = result.prize;
        this.canDraw = false;
        setTimeout(() => { this.slotAnimating = false; this.showPrizeModal = true; }, 500);
      }
    } catch (error) {
      popupAjaxError(error);
      this.slotAnimating = false;
    } finally {
      this.isDrawing = false;
    }
  }

  async _finishExtraLottery() {
    try {
      const result = await ajax("/custom-plugin/checkin/extra-draw", { type: "POST" });
      if (result.success) {
        this.slot1 = this.slot2 = this.slot3 = "★";
        this.wonPrize = result.prize;
        this.userPoints = result.remaining_points;
        this.extraDrawsRemaining = result.extra_draws_remaining;
        this.canBuyDraw = this.extraDrawsRemaining > 0 && this.userPoints >= this.extraDrawCost;
        setTimeout(() => { this.slotAnimating = false; this.showPrizeModal = true; }, 500);
      }
    } catch (error) {
      popupAjaxError(error);
      this.slotAnimating = false;
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

            {{#if this.showSlotMachine}}
              <div class="slot-machine {{if this.slotAnimating 'animating'}}">
                <div class="slot-container">
                  <div class="slot-reel"><span class="slot-symbol">{{this.slot1}}</span></div>
                  <div class="slot-reel"><span class="slot-symbol">{{this.slot2}}</span></div>
                  <div class="slot-reel"><span class="slot-symbol">{{this.slot3}}</span></div>
                </div>
              </div>
            {{/if}}

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

      {{#if this.showPrizeModal}}
        <div class="prize-modal-overlay" {{on "click" this.closePrizeModal}}>
          <div class="prize-modal" {{on "click" this.stopPropagation}}>
            <h3>{{i18n "custom_plugin.checkin.lottery.congratulations"}}</h3>
            <div class="prize-display">{{this.wonPrize}}</div>
            <button {{on "click" this.closePrizeModal}}>{{i18n "custom_plugin.checkin.lottery.ok"}}</button>
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
