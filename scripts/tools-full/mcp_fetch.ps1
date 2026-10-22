# mcp_fetch.ps1 - drive the remote "Web MCP" browser over SSE JSON-RPC
# usage: powershell -NoProfile -ExecutionPolicy Bypass -File mcp_fetch.ps1 -Urls "https://a","https://b" [-Full]
param(
  [Parameter(Mandatory=$true)][string[]]$Urls,
  [switch]$Full
)

Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue

$base   = 'https://web-mcp.koyeb.app'
$sseUrl = "$base/sse/1c0f3221-d9c2-4830-8ec8-e9b1b2e83cf0"

$getC  = [System.Net.Http.HttpClient]::new(); $getC.Timeout  = [TimeSpan]::FromSeconds(600)
$postC = [System.Net.Http.HttpClient]::new(); $postC.Timeout = [TimeSpan]::FromSeconds(60)

$req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $sseUrl)
$req.Headers.TryAddWithoutValidation('Accept','text/event-stream') | Out-Null
$resp = $getC.SendAsync($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
$rd = [System.IO.StreamReader]::new($resp.Content.ReadAsStreamAsync().Result)

$ep = $null
while ($null -ne ($l = $rd.ReadLine())) {
  if ($l -like 'data: *') { $ep = ($l -replace '^data: ',''); break }
}
if (-not $ep) { Write-Output 'ERROR: no endpoint event'; exit 1 }
$msgUrl = "$base$ep"

function PostM($obj) {
  $json = $obj | ConvertTo-Json -Depth 20 -Compress
  $c = [System.Net.Http.StringContent]::new($json, [System.Text.Encoding]::UTF8, 'application/json')
  $r = $postC.PostAsync($msgUrl, $c).Result
  return [int]$r.StatusCode
}

function WaitFor($id, $timeoutSec = 120) {
  $deadline = (Get-Date).AddSeconds($timeoutSec)
  while ((Get-Date) -lt $deadline) {
    $line = $rd.ReadLine()
    if ($null -eq $line) { return $null }
    if ($line -like 'data: *') {
      $j = $line -replace '^data: ',''
      try { $o = $j | ConvertFrom-Json } catch { continue }
      $names = $o.PSObject.Properties.Name
      if (($names -contains 'id') -and ($o.id -eq $id) -and (($names -contains 'result') -or ($names -contains 'error'))) {
        return $j
      }
    }
  }
  return $null
}

function CallTool($id, $name, $arguments) {
  $st = PostM @{ jsonrpc='2.0'; id=$id; method='tools/call'; params=@{ name=$name; arguments=$arguments } }
  if ($st -ne 202) { Write-Output "  [post status $st]" }
  $r = WaitFor $id
  if (-not $r) { return $null }
  $o = $r | ConvertFrom-Json
  $txt = ($o.result.content | ForEach-Object { $_.text }) -join "`n"
  return $txt
}

# handshake
PostM @{ jsonrpc='2.0'; id=1; method='initialize'; params=@{ protocolVersion='2024-11-05'; capabilities=@{}; clientInfo=@{ name='dsh'; version='1.0' } } } | Out-Null
WaitFor 1 | Out-Null
PostM @{ jsonrpc='2.0'; method='notifications/initialized' } | Out-Null

$id = 10
foreach ($u in $Urls) {
  $id++
  Write-Output "==== $u ===="
  $txt = CallTool $id 'new-tab' @{ url = $u }
  if ($txt) {
    if ($Full) { Write-Output $txt }
    else { Write-Output $txt.Substring(0, [Math]::Min(20000, $txt.Length)) }
  } else {
    Write-Output '  (no snapshot returned)'
  }
}
