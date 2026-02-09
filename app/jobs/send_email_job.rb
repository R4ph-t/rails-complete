class SendEmailJob < ApplicationJob
  queue_as :mailers

  def perform(article_id)
    article = Article.find(article_id)
    Rails.logger.info "[SendEmailJob] Sending notification email for article ##{article.id}: '#{article.title}' by #{article.author}"

    # Simulate sending an email
    sleep 2

    Rails.logger.info "[SendEmailJob] Email sent for article ##{article.id}!"
  end
end
