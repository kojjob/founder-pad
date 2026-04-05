defmodule FounderPad.Content do
  use Ash.Domain

  resources do
    resource FounderPad.Content.Post do
      define(:create_post, action: :create)
      define(:update_post, action: :update)
      define(:publish_post, action: :publish)
      define(:schedule_post, action: :schedule)
      define(:archive_post, action: :archive)
      define(:list_published_posts, action: :published)
      define(:get_post_by_slug, action: :by_slug, args: [:slug])
      define(:list_scheduled_ready, action: :scheduled_ready)
    end

    resource FounderPad.Content.Category do
      define(:create_category, action: :create)
      define(:update_category, action: :update)
      define(:list_categories, action: :read)
    end

    resource FounderPad.Content.Tag do
      define(:create_tag, action: :create)
      define(:update_tag, action: :update)
      define(:list_tags, action: :read)
    end

    resource(FounderPad.Content.PostCategory)
    resource(FounderPad.Content.PostTag)

    resource FounderPad.Content.ChangelogEntry do
      define(:create_changelog_entry, action: :create)
      define(:update_changelog_entry, action: :update)
      define(:publish_changelog_entry, action: :publish)
      define(:list_published_changelog, action: :published)
    end
  end
end
