import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { modifier } from "ember-modifier";

const NAV_ITEMS = [
  { id: "user-guide", label: "User Guide & Perks", slug: "user-guide-perks", rotate: true, icon: "nav-user-guide.png", bg: "nav-bg-stripe-diag.png" },
  { id: "say-hi", label: "Say Hi To Everyone", slug: "say-hi-to-everyone", rotate: false, icon: "nav-say-hi.png", bg: null },
  { id: "spin-win", label: "Spin & WIN", slug: "check-in-to-win", rotate: true, icon: "nav-spin-win.png", bg: null },
  { id: "showcase", label: "Showcase & Story", slug: "showcase-stories", rotate: false, icon: "nav-showcase.png", bg: null },
  { id: "diy-crafting", label: "DIY & Crafting Club", slug: "diy-crafting-club", rotate: false, icon: "nav-diy.png", bg: null },
  { id: "nanci-diary", label: "Nanci's Diary", slug: "nancis-diary", rotate: false, icon: "nav-nanci.png", bg: "nav-bg-stripe-vert.png" },
  { id: "new-arrivals", label: "New Arrivals", slug: "new-arrivals", rotate: true, icon: "nav-new-arrivals.png", bg: null },
  { id: "exclusive", label: "Exclusive Deals", slug: "exclusive-deals", rotate: false, icon: "nav-exclusive.png", bg: null },
  { id: "assembly-faq", label: "Assembly Guide & FAQ", slug: "assembly-guide-faq", rotate: false, icon: "nav-assembly.png", bg: null },
];

function imgPath(filename) {
  return `/plugins/discourse-custom-plugin/images/${filename}`;
}

export default class CategoryNavBar extends Component {
  scrollRef = null;

  captureRef = modifier((element) => {
    this.scrollRef = element;
  });

  @action
  scroll(dir) {
    this.scrollRef?.scrollBy({ left: dir * 320, behavior: "smooth" });
  }

  <template>
    <div class="category-nav-bar">
      <div class="nav-inner">
        <button
          class="nav-arrow nav-arrow--left"
          type="button"
          aria-label="Scroll left"
          {{on "click" (fn this.scroll -1)}}
        >&lsaquo;</button>

        <div class="nav-scroll-area" {{this.captureRef}}>
          <div class="nav-items">
            {{#each NAV_ITEMS as |item|}}
              <a
                class="nav-card nav-card--{{item.id}} {{if item.rotate 'rotate-on-hover'}}"
                href="/c/{{item.slug}}"
              >
                {{#if item.bg}}
                  <img class="card-bg" src={{imgPath item.bg}} alt="" loading="lazy" />
                {{else}}
                  <div class="card-bg card-bg--solid"></div>
                {{/if}}
                <img class="card-icon" src={{imgPath item.icon}} alt={{item.label}} loading="lazy" />
                <span class="card-label">{{item.label}}</span>
              </a>
            {{/each}}
          </div>
        </div>

        <button
          class="nav-arrow nav-arrow--right"
          type="button"
          aria-label="Scroll right"
          {{on "click" (fn this.scroll 1)}}
        >&rsaquo;</button>
      </div>
    </div>
  </template>
}
