defmodule Device do
  use GenServer
  require Logger

  def init({cuid, requests}) do
    {:ok, {cuid, requests, fn -> 0 end}}
  end

  def init({cuid, requests, delay}) when delay > 0 do
    {:ok, {cuid, requests, fn -> :rand.uniform(delay) end}}
  end

  def handle_cast({:fire, sender}, {cuid, requests, delay} = state) do
    result = Enum.map(1..requests, fn req ->
      resp = HTTPoison.get! "http://www.google.de"
      Logger.info "Req(#{req})@#{cuid}: result: #{resp.status_code}"
      :timer.sleep(delay.())
      resp.status_code
    end)

    send(sender, {cuid, result})
    {:noreply, state}
  end
end

defmodule Devices do
  require Logger

  def create(count, requests) do
    Enum.map(1..count, fn device ->
      GenServer.start_link(Device, {
        "device-nr-#{device}",
        requests
      })
    end)
  end

  def create(count, requests, delay) do
    Enum.map(1..count, fn device ->
      GenServer.start_link(Device, {
        "device-nr-#{device}",
        requests,
        delay
      })
    end)
  end

  def serial(devices) do
    for {:ok, device} <- devices do
      GenServer.cast(device, {:fire, self()})
      receive do
        {cuid, result} ->
          Logger.info "#{cuid} finished"
      end
    end
  end

  def parallel(devices) do
    for {:ok, device} <- devices do
      Task.async(fn ->
        GenServer.cast(device, {:fire, self()})
        receive do
          {cuid, result} ->
            Logger.info "#{cuid} finished"
        end
      end)
    end
  end
end
