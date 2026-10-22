param([string]$Tool,[string]$Url='',[string]$Element='',[string]$Ref='',[string]$Text='',[string]$Key='',[int]$Id=0,[int]$TimeoutSec=90)
Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
$base='https://web-mcp.koyeb.app'
$sse="$base/sse/1c0f3221-d9c2-4830-8ec8-e9b1b2e83cf0"
$getC=[System.Net.Http.HttpClient]::new(); $getC.Timeout=[TimeSpan]::FromSeconds(120)
$postC=[System.Net.Http.HttpClient]::new(); $postC.Timeout=[TimeSpan]::FromSeconds(60)
$req=[System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get,$sse)
$req.Headers.TryAddWithoutValidation('Accept','text/event-stream')|Out-Null
$resp=$getC.SendAsync($req,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
$rd=[System.IO.StreamReader]::new($resp.Content.ReadAsStreamAsync().Result)
$ep=$null
for($i=0;$i -lt 40;$i++){ $l=$rd.ReadLine(); if($null -eq $l){break}; if($l -like 'data: *'){ $ep=($l -replace '^data: ',''); break } }
if(-not $ep){ 'ERROR: no endpoint'; exit 1 }
$msg="$base$ep"
function PostM($o){ $j=$o|ConvertTo-Json -Depth 30 -Compress; $c=[System.Net.Http.StringContent]::new($j,[System.Text.Encoding]::UTF8,'application/json'); $r=$postC.PostAsync($msg,$c).Result; return [int]$r.StatusCode }
PostM @{jsonrpc='2.0';id=1;method='initialize';params=@{protocolVersion='2024-11-05';capabilities=@{};clientInfo=@{name='dsh';version='1.0'}}} | Out-Null
$deadline=(Get-Date).AddSeconds(60)
while((Get-Date) -lt $deadline){ $l=$rd.ReadLine(); if($null -eq $l){break}; if($l -like '*"id":1*result*'){break} }
PostM @{jsonrpc='2.0';method='notifications/initialized'} | Out-Null
$arguments=@{}; if($Url){$arguments["url"]=$Url}; if($Element){$arguments["element"]=$Element}; if($Ref){$arguments["ref"]=$Ref}; if($Text){$arguments["text"]=$Text}; if($Key){$arguments["key"]=$Key}; if($Id -ne 0){$arguments["id"]=$Id}
$st = PostM @{jsonrpc='2.0';id=7;method='tools/call';params=@{name=$Tool;arguments=$arguments}}
$deadline=(Get-Date).AddSeconds($TimeoutSec)
while((Get-Date) -lt $deadline){
  $l=$rd.ReadLine(); if($null -eq $l){break}
  if($l -like 'data: *'){
    $j=$l -replace '^data: ',''
    try { $o = $j | ConvertFrom-Json } catch { continue }
    if($o.PSObject.Properties.Name -contains 'id' -and $o.id -eq 7 -and (($o.PSObject.Properties.Name -contains 'result') -or ($o.PSObject.Properties.Name -contains 'error'))){
      if($o.error){ "ERROR: $($o.error.message)" }
      elseif($o.result.content){ $txt = ($o.result.content | ForEach-Object { $_.text }) -join "`n"; if([string]::IsNullOrEmpty($txt)){ $j } else { $txt } }
      else { $j }
      break
    }
  }
}