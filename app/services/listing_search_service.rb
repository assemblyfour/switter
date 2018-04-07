# frozen_string_literal: true

class ListingSearchService < BaseService
  attr_accessor :query

  def self.listings
    ::Status.tagged_with(Tag.find_by(name: 'swlisting'))
                       .local
                       .without_replies
                       .without_reblogs
                       .with_public_visibility
                       .excluding_silenced_accounts
                       .where('statuses.created_at > ?', 7.days.ago)
                       .where('LOWER(statuses.text) LIKE ?', '%location:%')
                       .order('statuses.created_at DESC')
  end

  def call(query)
    @query = query

    default_results.tap do |results|
      if query.blank?
        results[:listings] = all_listings
      else
        results[:listings] = perform_listing_search!
      end
    end
  end

  private

  def all_listings
    self.class.listings.limit(50)
  end

  def perform_listing_search!
     ListingsIndex.query(multi_match: { type: 'most_fields', query: query, operator: 'and', fields: %w(text text.stemmed location location.stemmed) })
                            .limit(50)
                            .order(created_at: {order: :desc})
                            .objects
                            .compact
  end

  def default_results
    { accounts: [], listings: [] }
  end

end
