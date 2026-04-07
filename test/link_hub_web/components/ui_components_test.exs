defmodule LinkHubWeb.Components.UiComponentsTest do
  use LinkHubWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias LinkHubWeb.CoreComponents
  alias LinkHubWeb.Skeleton

  describe "Skeleton.card/1" do
    test "renders a skeleton card with pulse animation" do
      html = render_component(&Skeleton.card/1, %{})

      assert html =~ "animate-pulse"
      assert html =~ "bg-surface-container"
      assert html =~ "rounded-xl"
      assert html =~ "bg-surface-container-highest"
    end

    test "accepts a custom class" do
      html = render_component(&Skeleton.card/1, %{class: "mt-4"})

      assert html =~ "mt-4"
      assert html =~ "animate-pulse"
    end
  end

  describe "Skeleton.table_row/1" do
    test "renders a skeleton table row with avatar and text placeholders" do
      html = render_component(&Skeleton.table_row/1, %{})

      assert html =~ "animate-pulse"
      assert html =~ "rounded-full"
      assert html =~ "bg-surface-container-highest"
    end

    test "accepts a custom class" do
      html = render_component(&Skeleton.table_row/1, %{class: "border-b"})

      assert html =~ "border-b"
    end
  end

  describe "Skeleton.text_block/1" do
    test "renders a skeleton text block with multiple lines" do
      html = render_component(&Skeleton.text_block/1, %{})

      assert html =~ "animate-pulse"
      assert html =~ "w-3/4"
      assert html =~ "w-1/2"
      assert html =~ "w-2/3"
    end

    test "accepts a custom class" do
      html = render_component(&Skeleton.text_block/1, %{class: "p-4"})

      assert html =~ "p-4"
    end
  end

  describe "CoreComponents.flash/1 (info)" do
    test "renders an info flash toast with primary accent" do
      html =
        render_component(&CoreComponents.flash/1, %{
          flash: %{"info" => "Operation successful"},
          kind: :info
        })

      assert html =~ "Operation successful"
      assert html =~ "border-primary"
      assert html =~ "info"
      assert html =~ "bg-surface-container-lowest"
      assert html =~ "glass-effect"
      assert html =~ "editorial-shadow"
      assert html =~ "rounded-xl"
      assert html =~ ~s(role="alert")
    end
  end

  describe "CoreComponents.flash/1 (error)" do
    test "renders an error flash toast with error accent" do
      html =
        render_component(&CoreComponents.flash/1, %{
          flash: %{"error" => "Something went wrong"},
          kind: :error
        })

      assert html =~ "Something went wrong"
      assert html =~ "border-error"
      assert html =~ "error"
      assert html =~ "bg-surface-container-lowest"
      assert html =~ "glass-effect"
      assert html =~ ~s(role="alert")
    end
  end

  describe "CoreComponents.flash/1 with no message" do
    test "does not render when flash is empty" do
      html =
        render_component(&CoreComponents.flash/1, %{
          flash: %{},
          kind: :info
        })

      refute html =~ "role=\"alert\""
    end
  end

  describe "CoreComponents.flash/1 close button" do
    test "renders a close button with accessible label" do
      html =
        render_component(&CoreComponents.flash/1, %{
          flash: %{"info" => "Test message"},
          kind: :info
        })

      assert html =~ ~s(aria-label="close")
      assert html =~ "hero-x-mark"
    end
  end
end
