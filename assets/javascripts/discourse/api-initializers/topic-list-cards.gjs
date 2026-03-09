import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.0.0", (api) => {
  try {
    api.registerValueTransformer("topic-list-columns", ({ value: columns }) => {
      columns.delete("posters");
      columns.delete("views");
      columns.delete("activity");
      return columns;
    });

    api.registerValueTransformer("topic-list-item-mobile-layout", () => false);
  } catch (e) {
    // registerValueTransformer may not exist in older Discourse
  }

  api.addSidebarSection(
    (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
      const MyPostsLink = class extends BaseCustomSidebarSectionLink {
        get name() { return "my-posts"; }
        get route() { return "userActivity"; }
        get models() { return [api.getCurrentUser()?.username]; }
        get text() { return "My Posts"; }
        get title() { return "My Posts"; }
        get prefixType() { return "icon"; }
        get prefixValue() { return "pencil-alt"; }
      };

      const MyMessagesLink = class extends BaseCustomSidebarSectionLink {
        get name() { return "my-messages"; }
        get route() { return "userPrivateMessages"; }
        get models() { return [api.getCurrentUser()?.username]; }
        get text() { return "my messages"; }
        get title() { return "My Messages"; }
        get prefixType() { return "icon"; }
        get prefixValue() { return "envelope"; }
      };

      const TopicsLink = class extends BaseCustomSidebarSectionLink {
        get name() { return "topics"; }
        get href() { return "/latest"; }
        get text() { return "Topics"; }
        get title() { return "Topics"; }
        get prefixType() { return "icon"; }
        get prefixValue() { return "heart"; }
      };

      const HelpLink = class extends BaseCustomSidebarSectionLink {
        get name() { return "help"; }
        get href() { return "/faq"; }
        get text() { return "Help"; }
        get title() { return "Help"; }
        get prefixType() { return "icon"; }
        get prefixValue() { return "question-circle"; }
      };

      const BadgesLink = class extends BaseCustomSidebarSectionLink {
        get name() { return "badges"; }
        get route() { return "badges"; }
        get text() { return "Badges"; }
        get title() { return "Badges"; }
        get prefixType() { return "icon"; }
        get prefixValue() { return "certificate"; }
      };

      return class extends BaseCustomSidebarSection {
        get name() { return "custom-quick-links"; }
        get title() { return "Quick Links"; }
        get text() { return "Quick Links"; }
        get links() {
          if (!api.getCurrentUser()) return [];
          return [
            new MyPostsLink(),
            new MyMessagesLink(),
            new TopicsLink(),
            new HelpLink(),
            new BadgesLink(),
          ];
        }
        get displaySection() { return true; }
      };
    }
  );
});
