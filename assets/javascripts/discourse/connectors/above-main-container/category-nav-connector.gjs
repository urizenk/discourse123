import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";

export default class CategoryBannerConnector extends Component {
  @service router;

  get category() {
    return this.args.outletArgs?.category;
  }

  get showBanner() {
    return !!this.category?.description;
  }

  get categoryName() {
    return this.category?.name || "";
  }

  get categoryDescription() {
    return htmlSafe(this.category?.description || "");
  }

  get categoryLogo() {
    return this.category?.uploaded_logo?.url;
  }

  get categoryColor() {
    const color = this.category?.color;
    return color ? `#${color}` : "#1a1a1a";
  }

  <template>
    {{#if this.showBanner}}
      <div class="category-header-banner">
        {{#if this.categoryLogo}}
          <div class="banner-icon">
            <img src={{this.categoryLogo}} alt={{this.categoryName}} />
          </div>
        {{/if}}
        <div class="banner-text">
          <h2 class="banner-title">{{this.categoryName}}</h2>
          <div class="banner-description">{{this.categoryDescription}}</div>
        </div>
      </div>
    {{/if}}
  </template>
}
