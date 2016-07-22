defmodule Device do
  use GenServer
  require Logger

  @url "http://testing-c4h2emvfexdttkyc67rebzcj-newenv.feedhenry.me/hello"

  defp build_header(cuid) do
    [
      "Origin": "https://testing.feedhenry.me",
      "Accept-Encoding": "gzip, deflate, br",
      "X-FH-projectid": "c4h2emtemdcrtw6qrvubreia",
      "Accept-Language": "en-US,en;q=0.8,zh-CN;q=0.6,zh;q=0.4",
      "Connection": "keep-alive",
      "X-FH-connectiontag": "0.0.1",
      "X-FH-sdk_version": "FH_JS_SDK/2.13.2-137",
      "Pragma": "no-cache",
      "X-FH-cuid": "#{cuid}",
      "X-FH-appid": "c4h2emvfexdttkyc67rebzcj",
      "User-Agent": " Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.84 Safari/537.36",
      "Content-Type": "application/json",
      "X-FH-cuidMap": "null",
      "Accept": "application/json",
      "Cache-Control": "no-cache",
      "X-FH-appkey": "6b93f504bb9e69da4779123e1ac4090b64c4abd5",
      "X-FH-destination": "studio"
    ]
  end

  defp body_build(cuid) do
    ~s({"hello":"perftool request","__fh":{"cuid":"#{cuid}","cuidMap":null,"destination":"studio","sdk_version":"FH_JS_SDK/2.13.2-137","appid":"c4h2emvfexdttkyc67rebzcj","appkey":"6b93f504bb9e69da4779123e1ac4090b64c4abd5","projectid":"c4h2emtemdcrtw6qrvubreia","connectiontag":"0.0.1"}})
  end

  def init({cuid, requests}) do
    {:ok, {cuid, requests, build_header(cuid), fn -> 0 end}}
  end

  def init({cuid, requests, delay}) when delay > 0 do
    {:ok, {cuid, requests, build_header(cuid), fn -> :rand.uniform(delay) end}}
  end

  def handle_cast({:fire, sender}, {cuid, requests, headers, delay} = state) do
    request = [
      body: body_build(cuid),
      headers: headers
    ]
 
    {_, a1, a2} = :erlang.timestamp

    Enum.map(1..requests, fn req ->
      resp = HTTPotion.post(@url, request)

      # Logger.info "Req(#{req})@#{cuid}: result: #{resp.status_code}"
      :timer.sleep(delay.())
      resp.status_code
    end)

    {_, b1, b2} = :erlang.timestamp

    aa = a1 + (a2 / 1000000)
    bb = b1 + (b2 / 1000000)
    diff = bb - aa

    send(sender, {cuid, diff})
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
          Logger.info "#{cuid} finished in #{result} seconds"
      end
    end
  end

  def parallel(devices) do
    for {:ok, device} <- devices do
      Task.async(fn ->
        GenServer.cast(device, {:fire, self()})
        receive do
          {cuid, result} ->
            Logger.info "#{cuid} finished in #{result} seconds"
        end
      end)
    end
  end
end
