# frozen_string_literal: true

class SwlistingsValidator < ActiveModel::Validator
  def validate(status)
    return unless status.local? && !status.reblog?
    return if status.reply? || status.private_visibility? || status.direct_visibility?
    return if status.account.user&.staff?

    tags = Extractor.extract_hashtags(status.text)

    return unless tags.map(&:downcase).include? 'swlisting'

    if status.account.created_at > 1.week.ago
      status.errors.add(:base, "Your account must be older than a week to post on the #swlisting hashtag")
      return
    end

    unless status.account.avatar?
      status.errors.add(:base, 'You need a profile picture to post on the #swlisting hashtag')
      return
    end

    ips = [status.account.user.current_sign_in_ip, status.account.user.last_sign_in_ip].compact.map(&:to_s).uniq

    swlisting_statuses = status.account.statuses.
                                tagged_with(Tag.find_by(name: 'swlisting')).
                                without_replies.
                                without_reblogs.
                                where(Status.arel_table[:updated_at].gt(1.day.ago))

    unless swlisting_statuses.count { |s| s.text =~ /#swlisting/ } < 3
      return status.errors.add(:base, 'You can only post 3 times per day to #swlisting')
    end

    if Report.joins(target_account: [:user]).
      where('current_sign_in_ip IN (?) OR last_sign_in_ip IN (?)', ips, ips).
      where('comment ~* ?', '.*(fake|spam|scam).*').
      distinct(:account_id).
      count >= 2
      status.errors.add(:base, "Your IP has been blocked for spam.")
      return
    end
  end
end
