class Article < ApplicationRecord
  has_many :comments, dependent: :destroy

  after_create_commit :enqueue_background_jobs

  def processed?
    processed_at.present?
  end

  private

  def enqueue_background_jobs
    ProcessArticleJob.perform_later(id)
    SendEmailJob.perform_later(id)
  end
end
