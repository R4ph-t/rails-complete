class ProcessArticleJob < ApplicationJob
  queue_as :default

  def perform(article_id)
    article = Article.find(article_id)
    Rails.logger.info "[ProcessArticleJob] Processing article ##{article.id}: #{article.title}"

    # Simulate heavy processing (e.g. generating a summary, indexing, etc.)
    sleep 5

    word_count = article.body.split.size
    article.update!(processed_at: Time.current)

    Rails.logger.info "[ProcessArticleJob] Done! Article ##{article.id} processed (#{word_count} words)"
  end
end
