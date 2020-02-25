#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.DataUpdaterPlant.RPC.Handler do
  @behaviour Astarte.RPC.Handler

  alias Astarte.DataUpdaterPlant.DataUpdater

  alias Astarte.RPC.Protocol.DataUpdaterPlant.{
    Call,
    DeleteVolatileTrigger,
    GenericErrorReply,
    GenericOkReply,
    InstallVolatileTrigger,
    Reply
  }

  require Logger

  def handle_rpc(payload) do
    with {:ok, call_tuple} <- extract_call_tuple(Call.decode(payload)) do
      call_rpc(call_tuple)
    end
  end

  defp extract_call_tuple(%Call{call: nil}) do
    Logger.warn("Received empty call")
    {:error, :empty_call}
  end

  defp extract_call_tuple(%Call{call: call_tuple}) do
    {:ok, call_tuple}
  end

  defp call_rpc(
         {:install_volatile_trigger,
          %InstallVolatileTrigger{
            realm_name: realm_name,
            device_id: device_id,
            object_id: object_id,
            object_type: object_type,
            parent_id: parent_id,
            simple_trigger_id: simple_trigger_id,
            simple_trigger: simple_trigger,
            trigger_target: trigger_target
          }}
       ) do
    with :ok <-
           DataUpdater.handle_install_volatile_trigger(
             realm_name,
             device_id,
             object_id,
             object_type,
             parent_id,
             simple_trigger_id,
             simple_trigger,
             trigger_target
           ) do
      %GenericOkReply{}
      |> encode_reply()
      |> ok_wrap()
    else
      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp call_rpc(
         {:delete_volatile_trigger,
          %DeleteVolatileTrigger{
            realm_name: realm_name,
            device_id: device_id,
            trigger_id: trigger_id
          }}
       ) do
    DataUpdater.handle_delete_volatile_trigger(
      realm_name,
      device_id,
      trigger_id
    )

    %GenericOkReply{}
    |> encode_reply()
    |> ok_wrap()
  end

  defp generic_error(
         error_name,
         user_readable_message \\ nil,
         user_readable_error_name \\ nil,
         error_data \\ nil
       ) do
    %GenericErrorReply{
      error_name: to_string(error_name),
      user_readable_message: user_readable_message,
      user_readable_error_name: user_readable_error_name,
      error_data: error_data
    }
    |> encode_reply(:generic_error_reply)
    |> ok_wrap
  end

  defp encode_reply(%GenericOkReply{} = reply) do
    %Reply{reply: {:generic_ok_reply, reply}, error: false}
    |> Reply.encode()
  end

  defp encode_reply(%GenericErrorReply{} = reply, _reply_type) do
    %Reply{reply: {:generic_error_reply, reply}, error: true}
    |> Reply.encode()
  end

  defp encode_reply(reply, reply_type) do
    %Reply{reply: {reply_type, reply}, error: false}
    |> Reply.encode()
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
