Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
$base='https://web-mcp.koyeb.app'
$sse="$base/sse/1c0f3221-d9c2-4830-8ec8-e9b1b2e83cf0"
$getC=[System.Net.Http.HttpClient]::new(); $getC.Timeout=[TimeSpan]::FromSeconds(120)
$postC=[System.Net.Http.HttpClient]::new(); $postC.Timeout=[TimeSpan]::FromSeconds(60)
$req=[System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get,$sse)
$req.Headers.TryAddWithoutValidation('Accept','text/event-stream')|Out-Null
try { $resp=$getC.SendAsync($req,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result } catch { "SSE ERR: $($_.Exception.Message)"; exit 1 }
"SSE status: $($resp.StatusCode)"
$rd=[System.IO.StreamReader]::new($resp.Content.ReadAsStreamAsync().Result)
$ep=$null
for($i=0;$i -lt 40;$i++){ $l=$rd.ReadLine(); if($null -eq $l){break}; "RAW: $l"; if($l -like 'data: *'){ $ep=($l -replace '^data: ',''); break } }
if(-not $ep){ "no endpoint"; exit 1 }
$msg="$base$ep"; "endpoint: $msg"
function PostM($o){ $j=$o|ConvertTo-Json -Depth 20 -Compress; "POST $j"; $c=[System.Net.Http.StringContent]::new($j,[System.Text.Encoding]::UTF8,'application/json'); $r=$postC.PostAsync($msg,$c).Result; "  -> $([int]$r.StatusCode)" }
PostM @{jsonrpc='2.0';id=1;method='initialize';params=@{protocolVersion='2024-11-05';capabilities=@{};clientInfo=@{name='dsh';version='1.0'}}}
$deadline=(Get-Date).AddSeconds(60)
while((Get-Date) -lt $deadline){ $l=$rd.ReadLine(); if($null -eq $l){break}; "RECV: $l"; if($l -like '*"id":1*'){break} }
PostM @{jsonrpc='2.0';method='notifications/initialized'}
PostM @{jsonrpc='2.0';id=2;method='tools/list';params=@{}}
$deadline=(Get-Date).AddSeconds(60)
while((Get-Date) -lt $deadline){ $l=$rd.ReadLine(); if($null -eq $l){break}; "RECV: $l"; if($l -like '*"id":2*'){break} }