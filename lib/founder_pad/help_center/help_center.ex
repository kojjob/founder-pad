defmodule FounderPad.HelpCenter do
  use Ash.Domain

  resources do
    resource FounderPad.HelpCenter.Category do
      define(:list_categories, action: :read)
      define(:create_category, action: :create)
      define(:update_category, action: :update)
    end

    resource FounderPad.HelpCenter.Article do
      define(:create_article, action: :create)
      define(:update_article, action: :update)
      define(:publish_article, action: :publish)
      define(:list_published_articles, action: :published)
      define(:list_articles_by_category, action: :by_category, args: [:category_id])
      define(:search_articles, action: :search, args: [:query])
    end

    resource FounderPad.HelpCenter.ContactRequest do
      define(:create_contact_request, action: :create)
    end
  end
end
