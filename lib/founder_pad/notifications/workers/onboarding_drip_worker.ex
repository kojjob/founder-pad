defmodule FounderPad.Notifications.Workers.OnboardingDripWorker do
  @moduledoc "Sends onboarding drip emails on day 1, 3, and 7."
  use Oban.Worker, queue: :mailers, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "day" => day}}) do
    user = Ash.get!(FounderPad.Accounts.User, user_id)

    # Check if user has opted out
    prefs = user.email_preferences || %{}

    if prefs["product_updates"] != false do
      case day do
        1 -> FounderPad.Notifications.OnboardingMailer.day_one_tips(user)
        3 -> FounderPad.Notifications.OnboardingMailer.day_three_check_in(user)
        _ -> :ok
      end
    end

    :ok
  end
end
