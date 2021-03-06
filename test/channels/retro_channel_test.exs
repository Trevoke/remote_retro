defmodule RemoteRetro.RetroChannelTest do
  use RemoteRetro.ChannelCase, async: false
  use Bamboo.Test, shared: true

  alias RemoteRetro.{RetroChannel, Repo, Idea, Presence, Retro}

  @mock_user Application.get_env(:remote_retro, :mock_user)

  defp join_the_retro_channel(%{retro: retro} = context) do
    {:ok, _, socket} =
      socket("", %{user_token: Phoenix.Token.sign(socket(), "user", @mock_user)})
      |> subscribe_and_join(RetroChannel, "retro:" <> retro.id)

    Map.put(context, :socket, socket)
  end

  describe "joining a RetroChannel" do
    setup [:join_the_retro_channel]

    test "assigns the retro_id to the socket", %{socket: socket, retro: retro} do
      assert socket.assigns.retro_id == retro.id
    end

    test "results in the push of a presence state to the new user" do
      assert_push "presence_state", %{}
    end

    test "results in a push of the retro state, including the `ideas` association" do
      assert_push "retro_state", %Retro{ideas: _, stage: "idea-generation"}
    end

    test "results in a Presence tracking of the new user, including timestamp", %{retro: retro} do
      result = Presence.list("retro:" <> retro.id)

      presence_object =
        Map.values(result)
        |> List.first
        |> Map.get(:metas)
        |> List.first

      assert presence_object["email"] == @mock_user["email"]
      assert presence_object["given_name"] == @mock_user["given_name"]
      assert presence_object["family_name"] == @mock_user["family_name"]
      assert %{online_at: _} = presence_object
    end
  end

  describe "pushing `proceed_to_next_stage` with a stage of 'action-item-distribution'" do
    setup [:join_the_retro_channel]

    test "broadcasts the same event to connected clients, along with stage", %{socket: socket} do
      push(socket, "proceed_to_next_stage", %{stage: "action-item-distribution"})

      assert_broadcast("proceed_to_next_stage", %{"stage" => "action-item-distribution"})
    end
  end

  describe "pushing a `proceed_to_next_stage` event" do
    setup [:join_the_retro_channel]
    test "broadcasts the same event to connected clients, along with stage", %{socket: socket} do
      push(socket, "proceed_to_next_stage", %{stage: "action-items"})

      assert_broadcast("proceed_to_next_stage", %{"stage" => "action-items"})
    end

    test "updates the retro stage to the value from the pushed event", %{socket: socket, retro: retro} do
      push(socket, "proceed_to_next_stage", %{stage: "action-items"})

      assert_broadcast("proceed_to_next_stage", %{"stage" => "action-items"})
      persisted_stage = Repo.get(Retro, retro.id).stage
      assert persisted_stage == "action-items"
    end

    test "doesn't send an email containing the retro action items", %{socket: socket} do
      push(socket, "proceed_to_next_stage", %{stage: "action-items"})
      assert_no_emails_delivered()
    end
  end

  describe "pushing a new idea to the socket" do
    setup [:join_the_retro_channel]
    test "results in the broadcast of the new idea to all connected clients", %{socket: socket} do
      push(socket, "new_idea", %{category: "happy", body: "we're pacing well", author: "Travis"})

      assert_broadcast("new_idea_received", %{category: "happy", body: "we're pacing well", id: _, author: "Travis"})
    end
  end

  describe "pushing an `enable_edit_state` event to the socket" do
    setup [:join_the_retro_channel]
    test "broadcasts the same event with the given payload", %{socket: socket} do
      push(socket, "enable_edit_state", %{id: 4})

      assert_broadcast("enable_edit_state", %{"id" => 4})
    end
  end

  describe "pushing an `disable_edit_state` event to the socket" do
    setup [:join_the_retro_channel]
    test "broadcasts the same event with the given payload", %{socket: socket} do
      push(socket, "disable_edit_state", %{id: 4})

      assert_broadcast("disable_edit_state", %{"id" => 4})
    end
  end

  describe "pushing a `user_typing_idea` event to the socket" do
    setup [:join_the_retro_channel]
    test "broadcasts the same event with the given payload", %{socket: socket} do
      push(socket, "user_typing_idea", %{userToken: "insaneToken"})

      assert_broadcast("user_typing_idea", %{"userToken" => "insaneToken"})
    end
  end

  describe "pushing an `idea_live_edit` event to the socket" do
    setup [:join_the_retro_channel]
    test "broadcasts the same event with the given payload", %{socket: socket} do
      push(socket, "idea_live_edit", %{id: 4, liveEditText: "updated"})

      assert_broadcast("idea_live_edit", %{"id" => 4, "liveEditText" => "updated"})
    end
  end

  describe "pushing an edit of an idea to the socket" do
    setup [:persist_idea_for_retro, :join_the_retro_channel]

    @tag idea: %Idea{category: "sad", body: "JavaScript", author: "Maryanne"}
    test "results in the broadcast of the edited idea to all connected clients", %{socket: socket, idea: idea} do
      idea_id = idea.id
      push(socket, "idea_edited", %{id: idea_id, body: "hell's bells"})

      assert_broadcast("idea_edited", %{body: "hell's bells", id: ^idea_id})
    end

    @tag idea: %Idea{category: "sad", body: "doggone keeper", author: "Maryanne"}
    test "results in the idea being updated in the database", %{socket: socket, idea: idea} do
      idea_id = idea.id
      push(socket, "idea_edited", %{id: idea_id, body: "hell's bells"})

      :timer.sleep(50)
      idea = Repo.get!(Idea, idea_id)
      assert idea.body == "hell's bells"
    end
  end

  describe "pushing a delete event to the socket" do
    setup [:join_the_retro_channel, :persist_idea_for_retro]

    @tag idea: %Idea{category: "sad", body: "WIP commits on master", author: "Zander"}
    test "results in a broadcast of the id of the deleted idea to all clients", %{socket: socket, idea: idea} do
      idea_id = idea.id
      push(socket, "delete_idea", idea_id)

      assert_broadcast("idea_deleted", %{id: ^idea_id})
    end
  end

  describe "the emission of a `presence_diff` event" do
    setup [:join_the_retro_channel]

    test "does not make its way to the client", %{socket: socket} do
      broadcast_from socket, "presence_diff", %{}
      refute_push "presence_diff", %{}
    end

    test "results in the push of a `presence_state` event", %{socket: socket} do
      broadcast_from socket, "presence_diff", %{}
      assert_push "presence_state", %{}
    end
  end
end
