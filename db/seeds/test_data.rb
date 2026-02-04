# frozen_string_literal: true

# 测试数据生成脚本
# 在 Rails console 中运行: load "plugins/discourse-custom-plugin/db/seeds/test_data.rb"

puts "Creating test data..."

# 获取或创建测试用户
user = User.find_by(username: "user1") || User.create!(
  username: "user1",
  email: "user1@example.com",
  password: "password123",
  active: true,
  approved: true
)

# 获取默认分类
category = Category.find_by(slug: "general") || Category.first

# 创建测试帖子
test_topics = [
  {
    title: "My First Robotime Model - Cello",
    body: "Just finished building my first Robotime model! The Cello music box took me about 6 hours to complete. The details are amazing and the sound is beautiful. Highly recommend for beginners!"
  },
  {
    title: "Tips for Building Complex Models",
    body: "After building 10+ models, here are my top tips:\n\n1. Always organize your pieces first\n2. Use a small amount of glue\n3. Take breaks to avoid eye strain\n4. Follow the instructions carefully\n5. Don't rush the assembly"
  },
  {
    title: "Showcase: My Robotime Collection",
    body: "Here's my growing collection of Robotime models:\n\n- Music Box: Cello\n- Marble Run: Tower Coaster\n- Clock: Owl Clock\n- DIY House: Simon's Coffee\n\nWhat should I build next?"
  },
  {
    title: "Need Help with Gear Assembly",
    body: "I'm stuck on step 45 of the Marble Run. The gears don't seem to mesh properly. Has anyone else had this issue? Any tips would be appreciated!"
  },
  {
    title: "Review: Owl Clock Model",
    body: "⭐⭐⭐⭐⭐ (5/5)\n\nJust finished the Owl Clock and it's fantastic! The mechanism works perfectly and keeps accurate time. Build quality is excellent. Took about 8 hours."
  }
]

test_topics.each do |topic_data|
  # 检查是否已存在
  existing = Topic.find_by(title: topic_data[:title])
  next if existing
  
  begin
    PostCreator.create!(
      user,
      title: topic_data[:title],
      raw: topic_data[:body],
      category: category.id,
      skip_validations: true
    )
    puts "Created topic: #{topic_data[:title]}"
  rescue => e
    puts "Failed to create topic: #{e.message}"
  end
end

# 创建签到测试数据
if defined?(DiscourseCustomPlugin::UserCheckin)
  unless DiscourseCustomPlugin::UserCheckin.where(user_id: user.id).exists?
    DiscourseCustomPlugin::UserCheckin.create!(
      user_id: user.id,
      checked_in_at: Time.current,
      points_earned: 10,
      consecutive_days: 1
    )
    puts "Created checkin data for user1"
  end
end

# 创建待办测试数据
if defined?(DiscourseCustomPlugin::UserTodo)
  todos = [
    { title: "Build the new Clock Model", list_type: "todo", completed: false },
    { title: "Post my finished Cello model", list_type: "todo", completed: true },
    { title: "Get the limited edition music box", list_type: "wish", completed: false }
  ]
  
  todos.each do |todo|
    unless DiscourseCustomPlugin::UserTodo.where(user_id: user.id, title: todo[:title]).exists?
      DiscourseCustomPlugin::UserTodo.create!(
        user_id: user.id,
        title: todo[:title],
        list_type: todo[:list_type],
        completed: todo[:completed]
      )
      puts "Created todo: #{todo[:title]}"
    end
  end
end

puts "Test data creation complete!"
