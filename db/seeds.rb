# Clear existing data
Comment.destroy_all
Article.destroy_all

# Create articles
10.times do |i|
  article = Article.create!(
    title: "Article #{i+1}",
    body: "This is the body of article #{i+1}. Lorem ipsum dolor sit amet.",
    author: ["Alice", "Bob", "Charlie"].sample
  )
  
  # Add 2-5 comments per article
  rand(2..5).times do |j|
    article.comments.create!(
      body: "Comment #{j+1} on article #{i+1}"
    )
  end
end

puts "Created #{Article.count} articles and #{Comment.count} comments"
