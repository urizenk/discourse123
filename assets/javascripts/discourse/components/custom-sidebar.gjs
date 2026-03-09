import Component from "@glimmer/component";
import { service } from "@ember/service";

const MENU_ITEMS = [
  { id: "my-posts", label: "My Posts", icon: "📝", href: "/my/activity" },
  { id: "my-messages", label: "my messages", icon: "💬", href: "/my/messages" },
  { id: "invite-friends", label: "Invite Friends", icon: "👥", href: "/my/invited" },
  { id: "topics", label: "Topics", icon: "❤️", href: "/my/activity/topics" },
  { id: "help", label: "Help", icon: "📋", href: "/faq" },
  { id: "how-to", label: "How To", icon: "💻", href: "/c/assembly-guide-faq" },
  { id: "badges", label: "Badges", icon: "🏆", href: "/badges" },
];

export default class CustomSidebar extends Component {
  @service router;

  get menuItems() {
    const currentPath = this.router.currentURL || "";
    return MENU_ITEMS.map((item) => ({
      ...item,
      isActive: currentPath.startsWith(item.href),
    }));
  }

  <template>
    <div class="custom-sidebar-menu">
      {{#each this.menuItems as |item|}}
        <a
          class="sidebar-menu-item {{if item.isActive 'active'}}"
          href={{item.href}}
        >
          <span class="menu-icon">{{item.icon}}</span>
          <span>{{item.label}}</span>
        </a>
      {{/each}}
    </div>
  </template>
}
