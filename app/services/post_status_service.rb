class PostStatusService < BaseService
  # Post a text status update, fetch and notify remote users mentioned
  # @param [Account] account Account from which to post
  # @param [String] text Message
  # @param [Status] in_reply_to Optional status to reply to
  # @param [Enumerable] media_ids Optional array of media IDs to attach
  # @return [Status]
  def call(account, text, in_reply_to = nil, media_ids = nil)
    status = account.statuses.create!(text: text, thread: in_reply_to)
    attach_media(status, media_ids)
    process_mentions_service.call(status)
    DistributionWorker.perform_async(status.id)
    HubPingWorker.perform_async(account.id)
    status
  end

  private

  def attach_media(status, media_ids)
    return if media_ids.nil? || !media_ids.is_a?(Enumerable)

    media = MediaAttachment.where(status_id: nil).where(id: media_ids.take(4).map(&:to_i))
    media.update(status_id: status.id)
  end

  def process_mentions_service
    @process_mentions_service ||= ProcessMentionsService.new
  end
end
