param(
  [ValidateSet("auto", "glm5.2", "minimax-m3")]
  [string]$Target = "auto",

  [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config.json"),
  [string]$RouterUrl = "",
  [int]$TimeoutSec = 120,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$Provider = "nvidia-glm"
$GlmModel = "z-ai/glm-5.2"
$MiniMaxModel = "minimaxai/minimax-m3"
$RouterKeys = @("default", "background", "think", "longContext", "webSearch", "image")

function Get-RouteValue([string]$model) {
  return "$Provider,$model"
}

function Get-ModelFromRoute([string]$route) {
  if (-not $route -or -not $route.Contains(",")) {
    return $null
  }

  return $route.Split(",", 2)[1]
}

function Set-RouterModel($config, [string]$model) {
  $route = Get-RouteValue $model

  foreach ($key in $RouterKeys) {
    if ($config.Router.PSObject.Properties.Name -contains $key) {
      $config.Router.$key = $route
    }
  }
}

function Save-Config($config, [string]$path) {
  $config | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path -Encoding UTF8
}

function Restart-Router {
  if ($DryRun) {
    Write-Output "[dry-run] ccr restart"
    return
  }

  ccr restart | Out-Null
}

function Invoke-MinimalRequest([string]$url) {
  if ($DryRun) {
    Write-Output "[dry-run] POST $url"
    return [pscustomobject]@{
      Ok = $true
      Status = 200
      Body = @{ model = "dry-run"; content = @(@{ type = "text"; text = "ok" }) }
    }
  }

  $body = @{
    model = "claude-haiku-4-5-20251001"
    max_tokens = 32
    stream = $false
    messages = @(
      @{ role = "user"; content = "Reply with only: ok" }
    )
  } | ConvertTo-Json -Depth 10

  try {
    $response = Invoke-RestMethod `
      -Method Post `
      -Uri $url `
      -ContentType "application/json" `
      -Body $body `
      -TimeoutSec $TimeoutSec

    return [pscustomobject]@{
      Ok = $true
      Status = 200
      Body = $response
    }
  } catch {
    $status = $null
    if ($_.Exception.Response) {
      $status = $_.Exception.Response.StatusCode.value__
    }

    return [pscustomobject]@{
      Ok = $false
      Status = $status
      Message = $_.Exception.Message
      Body = $_.ErrorDetails.Message
    }
  }
}

$resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$config = Get-Content -Raw -LiteralPath $resolvedConfigPath | ConvertFrom-Json
$originalModel = Get-ModelFromRoute $config.Router.default

if ($Target -eq "auto") {
  if ($originalModel -eq $GlmModel) {
    $targetModel = $MiniMaxModel
  } elseif ($originalModel -eq $MiniMaxModel) {
    $targetModel = $GlmModel
  } else {
    throw "Current Router.default model '$originalModel' is not one of: $GlmModel, $MiniMaxModel. Pass -Target explicitly."
  }
} elseif ($Target -eq "glm5.2") {
  $targetModel = $GlmModel
} else {
  $targetModel = $MiniMaxModel
}

if (-not $RouterUrl) {
  $hostName = $config.HOST
  if (-not $hostName) {
    $hostName = "127.0.0.1"
  }

  $port = $config.PORT
  if (-not $port) {
    $port = 3456
  }

  $RouterUrl = "http://${hostName}:${port}/v1/messages?beta=true"
}

Write-Output "Current model: $originalModel"
Write-Output "Target model:  $targetModel"

Set-RouterModel $config $targetModel
if ($DryRun) {
  Write-Output "[dry-run] update Router entries in $resolvedConfigPath"
} else {
  Save-Config $config $resolvedConfigPath
}
Restart-Router

$result = Invoke-MinimalRequest $RouterUrl

if ($result.Ok) {
  $responseModel = $result.Body.model
  $text = ""
  if ($result.Body.content -and $result.Body.content.Count -gt 0) {
    $text = $result.Body.content[0].text
  }

  Write-Output "STATUS=200"
  Write-Output "Kept model: $targetModel"
  Write-Output "Response model: $responseModel"
  Write-Output "Text: $text"
  exit 0
}

Write-Output "STATUS=$($result.Status)"
Write-Output "Request failed, restoring model: $originalModel"
if ($result.Message) {
  Write-Output "MESSAGE=$($result.Message)"
}
if ($result.Body) {
  Write-Output $result.Body
}

$config = Get-Content -Raw -LiteralPath $resolvedConfigPath | ConvertFrom-Json
Set-RouterModel $config $originalModel
if ($DryRun) {
  Write-Output "[dry-run] restore Router entries in $resolvedConfigPath"
} else {
  Save-Config $config $resolvedConfigPath
}
Restart-Router

exit 1
