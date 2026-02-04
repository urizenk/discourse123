import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";

export default apiInitializer("1.0.0", (api) => {
  // 加载用户自定义表情
  let customEmojis = [];
  let customEmojisLoaded = false;
  
  async function loadCustomEmojis() {
    if (customEmojisLoaded) return customEmojis;
    
    try {
      const result = await ajax("/custom-plugin/custom-emoji");
      customEmojis = result.emojis || [];
      customEmojisLoaded = true;
    } catch (error) {
      console.error("Failed to load custom emojis:", error);
    }
    
    return customEmojis;
  }
  
  // 在编辑器工具栏添加自定义表情按钮
  api.onToolbarCreate((toolbar) => {
    toolbar.addButton({
      id: "custom-emoji",
      group: "extras",
      icon: "far-smile",
      title: "Insert Custom Emoji",
      perform: async (e) => {
        const emojis = await loadCustomEmojis();
        
        if (emojis.length === 0) {
          alert("You haven't uploaded any custom emoji yet. Go to your profile to add some!");
          return;
        }
        
        // 创建表情选择弹窗
        showCustomEmojiPicker(e, emojis);
      }
    });
  });
  
  // 在Composer中注册表情支持
  api.modifyClass("component:emoji-picker", {
    pluginId: "custom-emoji-plugin",
    
    didInsertElement() {
      this._super(...arguments);
      this._loadCustomEmojis();
    },
    
    async _loadCustomEmojis() {
      const emojis = await loadCustomEmojis();
      
      if (emojis.length > 0) {
        // 添加自定义表情分类到选择器
        this._addCustomEmojiSection(emojis);
      }
    },
    
    _addCustomEmojiSection(emojis) {
      const picker = document.querySelector(".emoji-picker");
      if (!picker) return;
      
      // 检查是否已添加
      if (picker.querySelector(".custom-emoji-section")) return;
      
      // 创建自定义表情区域
      const section = document.createElement("div");
      section.className = "custom-emoji-section";
      section.innerHTML = `
        <div class="section-header">
          <span>My Emoji</span>
        </div>
        <div class="custom-emoji-grid">
          ${emojis.map(emoji => `
            <button 
              class="custom-emoji-btn" 
              data-emoji-name="${emoji.name}"
              data-emoji-url="${emoji.url}"
              title=":${emoji.name}:"
            >
              <img src="${emoji.url}" alt="${emoji.name}" />
            </button>
          `).join("")}
        </div>
      `;
      
      // 绑定点击事件
      section.querySelectorAll(".custom-emoji-btn").forEach(btn => {
        btn.addEventListener("click", () => {
          const name = btn.dataset.emojiName;
          const url = btn.dataset.emojiUrl;
          this._insertCustomEmoji(name, url);
        });
      });
      
      // 插入到选择器顶部
      const content = picker.querySelector(".emoji-picker-content");
      if (content) {
        content.insertBefore(section, content.firstChild);
      }
    },
    
    _insertCustomEmoji(name, url) {
      // 插入图片markdown
      const img = `![${name}](${url})`;
      this.emojiSelected(img);
    }
  });
  
  // 监听页面变化，在编辑器中注入自定义表情支持
  api.onPageChange(() => {
    injectCustomEmojiSupport();
  });
});

// 显示自定义表情选择器
function showCustomEmojiPicker(editor, emojis) {
  // 如果弹窗已存在，移除
  const existing = document.querySelector(".custom-emoji-picker-modal");
  if (existing) existing.remove();
  
  const modal = document.createElement("div");
  modal.className = "custom-emoji-picker-modal";
  modal.innerHTML = `
    <div class="custom-emoji-picker-overlay"></div>
    <div class="custom-emoji-picker-content">
      <div class="picker-header">
        <h4>My Custom Emoji</h4>
        <button class="picker-close">&times;</button>
      </div>
      <div class="picker-grid">
        ${emojis.map(emoji => `
          <button 
            class="picker-emoji" 
            data-name="${emoji.name}"
            data-url="${emoji.url}"
            title=":${emoji.name}:"
          >
            <img src="${emoji.url}" alt="${emoji.name}" />
          </button>
        `).join("")}
      </div>
    </div>
  `;
  
  document.body.appendChild(modal);
  
  // 关闭按钮
  modal.querySelector(".picker-close").addEventListener("click", () => modal.remove());
  modal.querySelector(".custom-emoji-picker-overlay").addEventListener("click", () => modal.remove());
  
  // 表情点击
  modal.querySelectorAll(".picker-emoji").forEach(btn => {
    btn.addEventListener("click", () => {
      const name = btn.dataset.name;
      const url = btn.dataset.url;
      
      // 插入图片markdown到编辑器
      editor.addText(`![${name}](${url})`);
      modal.remove();
    });
  });
}

// 注入自定义表情支持到编辑器
function injectCustomEmojiSupport() {
  // 监听emoji picker的打开
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === 1 && node.classList?.contains("emoji-picker")) {
          injectCustomEmojisIntoNativePicker(node);
        }
      });
    });
  });
  
  observer.observe(document.body, { childList: true, subtree: true });
}

// 将自定义表情注入到原生表情选择器
async function injectCustomEmojisIntoNativePicker(picker) {
  // 检查是否已注入
  if (picker.querySelector(".custom-emoji-section")) return;
  
  try {
    const result = await ajax("/custom-plugin/custom-emoji");
    const emojis = result.emojis || [];
    
    if (emojis.length === 0) return;
    
    // 创建自定义表情区域
    const section = document.createElement("div");
    section.className = "custom-emoji-section";
    section.innerHTML = `
      <div class="emoji-section-header">My Emoji</div>
      <div class="custom-emoji-list">
        ${emojis.map(emoji => `
          <button 
            type="button"
            class="emoji custom-emoji-item" 
            data-emoji=":${emoji.name}:"
            data-url="${emoji.url}"
            title=":${emoji.name}:"
          >
            <img src="${emoji.url}" alt="${emoji.name}" loading="lazy" />
          </button>
        `).join("")}
      </div>
    `;
    
    // 插入到选择器
    const emojiArea = picker.querySelector(".emoji-picker-emoji-area");
    if (emojiArea) {
      emojiArea.insertBefore(section, emojiArea.firstChild);
    }
    
    // 绑定点击事件
    section.querySelectorAll(".custom-emoji-item").forEach(btn => {
      btn.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        
        const url = btn.dataset.url;
        const name = btn.dataset.emoji;
        
        // 获取编辑器textarea
        const textarea = document.querySelector(".d-editor-input");
        if (textarea) {
          const start = textarea.selectionStart;
          const end = textarea.selectionEnd;
          const text = textarea.value;
          const insertion = `![emoji](${url})`;
          
          textarea.value = text.substring(0, start) + insertion + text.substring(end);
          textarea.selectionStart = textarea.selectionEnd = start + insertion.length;
          textarea.focus();
          
          // 触发input事件
          textarea.dispatchEvent(new Event("input", { bubbles: true }));
        }
        
        // 关闭picker
        const closeBtn = picker.querySelector(".emoji-picker-close");
        if (closeBtn) closeBtn.click();
      });
    });
  } catch (error) {
    console.error("Failed to inject custom emojis:", error);
  }
}
