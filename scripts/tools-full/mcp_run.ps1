param([string]$Steps,[int]$TimoutSec=120)
Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
$base='https://web-mcp.koyeb.app'
$sse="$base/sse/1c0f3221-d9c2-4830-8ec8-e9b1b2e83cf0"
$getC=[System.Net.Http.HttpClient]::new(); $getC.Timeout=[TimeSpan]::FromSeconds(120)
$postC=[System.Net.Http.HttpClient]::new(); $postC.Timeout=[TimeSpan]::FromSeconds(120)
$req=[System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get,$sse)
$req.Headers.TryAddWithoutValidation('Accept','text/event-stream')|Out-Null
$resp=$getC.SendAsync($req,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
$rd=[System.IO.StreamReader]::new($resp.Content.ReadAsStreamAsync().Result)
$ep=$null
for($i=0;$i -lt 40;$i++){ $l=$rd.ReadLine(); if($null -eq $l){break}; if($l -like 'data: *'){ $ep=($l -replace '^data: ',''); break } }
if(-not $ep){ 'ERROR: no endpoint'; exit 1 }
$msg="$base$ep"
$script:nextId=1
function PostM($o){ $j=$o|ConvertTo-Json -Depth 30 -Compress; $c=[System.Net.Http.StringContent]::new($j,[System.Text.Encoding]::UTF8,'application/json'); $r=$postC.PostAsync($msg,$c).Result; return [int]$r.StatusCode }
function CallTool($name,$arguments){
  $script:nextId++; $id=$script:nextId
  PostM @{jsonrpc='2.0';id=$id;method='tools/call';params=@{name=$name;arguments=$arguments}} | Out-Null
  $deadline=(Get-Date).AddSeconds($TimoutSec)
  while((Get-Date) -lt $deadline){
    $l=$rd.ReadLine(); if($null -eq $l){ return '[null-line]' }
    if($l -like 'data: *'){
      $j=$l -replace '^data: ',''
      try { $o=$j|ConvertFrom-Json } catch { continue }
      if(($o.PSObject.Properties.Name -contains 'id') -and $o.id -eq $id){
        if($o.PSObject.Properties.Name -contains 'error'){ return "ERROR: $($o.error.message)" }
        $txt = ($o.result.content | ForEach-Object { $_.text }) -join "`n"
        if([string]::IsNullOrEmpty($txt)){ return 'OK(empty)' }
        return $txt
      }
    }
  }
  return '[timeout]'
}
PostM @{jsonrpc='2.0';id=1;method='initialize';params=@{protocolVersion='2024-11-05';capabilities=@{};clientInfo=@{name='dsh';version='1.0'}}} | Out-Null
$dl=(Get-Date).AddSeconds(60); while((Get-Date) -lt $dl){ $l=$rd.ReadLine(); if($null -eq $l){break}; if($l -like '*"id":1*result*'){break} }
PostM @{jsonrpc='2.0';method='notifications/initialized'} | Out-Null
if($Steps -and (Test-Path $Steps)){ $list = (Get-Content $Steps -Raw -Encoding UTF8) | ConvertFrom-Json } else { $list = $Steps | ConvertFrom-Json }
foreach($s in $list){
  if($s.tool -eq 'LIST'){
    $script:nextId++; $id=$script:nextId
    PostM @{jsonrpc='2.0';id=$id;method='tools/list';params=@{}} | Out-Null
    $dl2=(Get-Date).AddSeconds(60)
    while((Get-Date) -lt $dl2){ $l=$rd.ReadLine(); if($null -eq $l){break}
      if($l -like 'data: *'){ $j=$l -replace '^data: ',''
        try{ $o=$j|ConvertFrom-Json }catch{ continue }
        if(($o.PSObject.Properties.Name -contains 'id') -and $o.id -eq $id){ ($o.result.tools | ForEach-Object { "TOOL $($_.name) :: " + (($_.inputSchema.properties.PSObject.Properties.Name) -join ',') }) -join "`n" | Write-Output; break }
      }
    }
    continue
  }
  "=== $($s.tool) ==="
  $a=@{}
  if($s.args){ $s.args.PSObject.Properties | ForEach-Object { $a[$_.Name]=$_.Value } }
  (CallTool $s.tool $a) | Write-Output
}